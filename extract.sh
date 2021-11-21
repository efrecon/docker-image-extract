#!/bin/sh

# If editing from Windows. Choose LF as line-ending


set -eu


# Set this to 1 for more verbosity (on stderr)
EXTRACT_VERBOSE=${EXTRACT_VERBOSE:-0}

# Destination directory, some %-surrounded keywords will be dynamically replaced
# by elements of the fully-qualified image name.
EXTRACT_DEST=${EXTRACT_DEST:-"$(pwd)"}

# Pull if the image does not exist. If the image had to be pulled, it will
# automatically be removed once done to conserve space.
EXTRACT_PULL=${EXTRACT_PULL:-1}

# Docker client command to use
EXTRACT_DOCKER=${EXTRACT_DOCKER:-"docker"}

# Name of manifest file containing the description of the layers
EXTRACT_MANIFEST=${EXTRACT_MANIFEST:-"manifest.json"}

# This uses the comments behind the options to show the help. Not extremly
# correct, but effective and simple.
usage() {
  echo "$0 extracts all layers from a Docker image to a directory, will pull if necessary" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "t:d:vnh-" opt; do
  case "$opt" in
    d) # How to run the Docker client
      EXTRACT_DOCKER=$OPTARG;;
    n) # Do not pull if the image does not exist
      EXTRACT_PULL=0;;
    h) # Print help and exit
      usage;;
    t) # Target directory, will be created if necessary, %-surrounded keywords will be resolved (see manual). Default: current directory
      EXTRACT_DEST=$OPTARG;;
    v) # Turn on verbosity
      EXTRACT_VERBOSE=1;;
    -)
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND-1))


_verbose() {
  if [ "$EXTRACT_VERBOSE" = "1" ]; then
    printf %s\\n "$1" >&2
  fi
}

_error() {
  printf %s\\n "$1" >&2
}


# This will unfold JSON onliners to arrange for having fields and their values
# on separated lines. It's sed and grep, don't expect miracles, but this should
# work against most well-formatted JSON.
json_unfold() {
  sed -E \
      -e 's/\}\s*,\s*\{/\n\},\n\{\n/g' \
      -e 's/\{\s*"/\{\n"/g' \
      -e 's/(.+)\}/\1\n\}/g' \
      -e 's/"\s*:\s*(("[^"]+")|([a-zA-Z0-9]+))\s*([,$])/": \1\4\n/g' \
      -e 's/"\s*:\s*(("[^"]+")|([a-zA-Z0-9]+))\s*\}/": \1\n\}/g' | \
    grep -vEe '^\s*$'
}

extract() {
  # Extract details out of image name
  fullname=$1
  tag=""
  if printf %s\\n "$1"|grep -Eq '@sha256:[a-f0-9A-F]{64}$'; then
    tag=$(printf %s\\n "$1"|grep -Eo 'sha256:[a-f0-9A-F]{64}$')
    fullname=$(printf %s\\n "$1"|sed -E 's/(.*)@sha256:[a-f0-9A-F]{64}$/\1/')
  elif printf %s\\n "$1"|grep -Eq ':[[:alnum:]_][[:alnum:]_.-]{0,127}$'; then
    tag=$(printf %s\\n "$1"|grep -Eo ':[[:alnum:]_][[:alnum:]_.-]{0,127}$'|cut -c 2-)
    fullname=$(printf %s\\n "$1"|sed -E 's/(.*):[[:alnum:]_][[:alnum:]_.-]{0,127}$/\1/')
  fi
  shortname=$(printf %s\\n "$fullname" | awk -F / '{printf $NF}')
  fullname_flat=$(printf %s\\n "$fullname" | sed 's~/~_~g')
  if [ -z "$tag" ]; then
    fullyqualified_flat=$(printf %s_%s\\n "$fullname_flat" "latest")
  else
    fullyqualified_flat=$(printf %s_%s\\n "$fullname_flat" "$tag")
  fi

  # Generate the name of the destination directory, replacing the
  # sugared-strings by their values. We use the ~ character as a separator in
  # the sed expressions as / might appear in the values.
  dst=$(printf %s\\n "$EXTRACT_DEST" |
        sed -E \
          -e "s~%tag%~${tag}~" \
          -e "s~%fullname%~${fullname}~" \
          -e "s~%shortname%~${shortname}~" \
          -e "s~%fullname_flat%~${fullname_flat}~" \
          -e "s~%fullyqualified_flat%~${fullyqualified_flat}~" \
          -e "s~%name%~${1}~" \
          )

  # Pull image on demand, if necessary and when EXTRACT_PULL was set to 1
  imgrm=0
  if ! ${EXTRACT_DOCKER} image inspect "$1" >/dev/null 2>&1 && [ "$EXTRACT_PULL" = "1" ]; then
    _verbose "Pulling image '$1', will remove it upon completion"
    ${EXTRACT_DOCKER} image pull "$1"
    imgrm=1
  fi

  if ${EXTRACT_DOCKER} image inspect "$1" >/dev/null 2>&1 ; then
    # Create a temporary directory to store the content of the image itself, i.e.
    # the result of docker image save on the image.
    TMPD=$(mktemp -t -d image-XXXXX)

    # Extract image to the temporary directory
    _verbose "Extracting content of '$1' to temporary storage"
    ${EXTRACT_DOCKER} image save "$1" | tar -C "$TMPD" -xf -

    # Create destination directory, if necessary
    if ! [ -d "$dst" ]; then
      _verbose "Creating destination directory: '$dst' (resolved from '$EXTRACT_DEST')"
      mkdir -p "$dst"
    fi

    # Extract all layers of the image, in the order specified by the manifest,
    # into the destination directory.
    if [ -f "${TMPD}/${EXTRACT_MANIFEST}" ]; then
      json_unfold < "${TMPD}/${EXTRACT_MANIFEST}" |
      grep -oE '[a-fA-F0-9]{64}/[[:alnum:]]+\.tar' |
      while IFS= read -r layer; do
        _verbose "Extracting layer $(printf %s\\n "$layer" | awk -F '/' '{print $1}')"
        tar -C "$dst" -xf "${TMPD}/${layer}"
      done
    else
      _error "Cannot find $EXTRACT_MANIFEST in image content!"
    fi

    # Remove temporary content of image save.
    rm -rf "$TMPD"
  else
    _error "Image $1 not present at Docker daemon"
  fi

  if [ "$imgrm" = "1" ]; then
    _verbose "Removing image $1 from host"
    ${EXTRACT_DOCKER} image rm "$1"
  fi
}

# We need at least one image
if [ "$#" = "0" ]; then
  usage
fi

# Extract all images, one by one, to the target directory
for i in "$@"; do
  extract "$i"
done
