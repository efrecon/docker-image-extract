#!/bin/sh

# If editing from Windows. Choose LF as line-ending


set -eu


# Set this to 1 for more verbosity (on stderr)
EXTRACT_VERBOSE=${EXTRACT_VERBOSE:-0}

# Destination directory
EXTRACT_DEST=${EXTRACT_DEST:-"$(pwd)"}

# Name of manifest file containing the description of the layers
EXTRACT_MANIFEST=${EXTRACT_MANIFEST:-"manifest.json"}

# This uses the comments behind the options to show the help. Not extremly
# correct, but effective and simple.
usage() {
  echo "$0 extracts all layers from a Docker image to a directory" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "d:vh-" opt; do
  case "$opt" in
    d) # Destination directory, will be created if necessary. Default: current directory
      EXTRACT_DEST=$OPTARG;;
    v) # Turn on verbosity
      EXTRACT_VERBOSE=1;;
    h) # Print help and exit
      usage;;
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
  # Create a temporary directory to store the content of the image itself, i.e.
  # the result of docker image save on the image.
  TMPD=$(mktemp -t -d image-XXXXX)

  # Extract image to the temporary directory
  _verbose "Extracting content of '$1' to temporary storage"
  docker image save "$1" | tar -C "$TMPD" -xf -

  # Create destination directory, if necessary
  if ! [ -d "$EXTRACT_DEST" ]; then
    _verbose "Creating destination directory: $EXTRACT_DEST"
    mkdir -p "$EXTRACT_DEST"
  fi

  # Extract all layers of the image, in the order specified by the manifest,
  # into the destination directory.
  if [ -f "${TMPD}/${EXTRACT_MANIFEST}" ]; then
    json_unfold < "${TMPD}/${EXTRACT_MANIFEST}" |
    grep -oE '[a-fA-F0-9]{64}/[[:alnum:]]+\.tar' |
    while IFS= read -r layer; do
      _verbose "Extracting layer $(printf %s\\n "$layer" | awk -F '/' '{print $1}')"
      tar -C "$EXTRACT_DEST" -xf "${TMPD}/${layer}"
    done
  else
    _error "Cannot find $EXTRACT_MANIFEST in image content!"
  fi

  # Remove temporary content of image save.
  rm -rf "$TMPD"
}

# We need at least one image
if [ "$#" = "0" ]; then
  usage
fi

# Extract all images, one by one, to the target directory
for i in "$@"; do
  extract "$i"
done
