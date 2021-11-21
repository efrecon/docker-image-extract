# docker-image-extract

This project implements both a [script](#command-line-options) and a GitHub
[Action](#github-action) that extracts all layers from a Docker image to a
directory. The script replaces the command that should have existed as
`docker image extract`. The script will extract all images passed as arguments
to a directory (default: current). Images are automatically been pulled if they
do not exist at the host. When pulling was necessary, images will be removed
once all their layers have been extracted.

## Requirements

This script has the following requirements:

+ Ability to run the `docker` command as the current user.
+ Minimal installation of `tar`, `grep` and `sed`, i.e. the ones from minimal
  implementations such as [busybox] will work.

  [busybox]: https://busybox.net/

## Command-Line Options

The script takes any number of Docker images as arguments. It also accepts a
number of options and flags. `--` can be used to explicitely mark the end of the
options and the beginning of the image list. Recognised options and flags are as
follows:

### Option `-d`

The value of this option specifies how to run the `docker` client. It defaults
to the string `docker`, meaning that the `docker` binary will be looked for in
the `$PATH`. While this hasn't been verified, this option should be able to pick
other command-line compatible alternatives to the `docker` client, e.g.
[`nerdctl`][nerdctl] or [`podman`][podman].

  [nerdctl]: https://github.com/containerd/nerdctl
  [podman]: https://github.com/containers/podman

### Flag `-n`

When this flag is specified, images that do not exist at the host will not be
automatically be pulled, then removed. The default is the opposite, i.e. images
that are not present at the host will automatically be pulled with the `pull`
sub-command to the Docker client, then removed with the `image rm` sub-command.
To detect if an image is present, [`extract.sh`](./extract.sh) will check the
return code of the `image inspect` sub-command.

### Option `-t`

The value of this option specifies the target directory where to the images
specified as arguments will be extracted. The directory will be created if it
does not exist. The default is the current directory. In order to ease
extraction of several images into several directories in one pass, a number of
`%`-surrounded keywords are recognised and will be dynamically replaced by their
value for each image name. These keywords are:

+ `%tag%` will be replaced by the tag of the image. When a digest is specified
  instead, this will be the digest, sans the leading `@` character. When no tag
  was specified, this will be empty.
+ `%fullname%` will be the full name of the image, sans the ending tag or
  digest. The `%fullname%` might contain `/`.
+ `%shortname%` is the last item in the `/`-separated hierarchy of the
  `%fullname%`.
+ `%fullname_flat%` is the same as the `%fullname%`, but with all `/` (slashes)
  replaced by the `_` (underscore) character.
+ `%fullyqualified_flat%` is the concatenation of `%fullname_flat%` and the
  `%tag%` with an `_` (underscore) character as a separator. In that case, when
  no tag was specified, it will be printed out as `latest`.
+ `%name%` is the same as the name of the image, without any further analysis.

Provided `efrecon/kubectl:v1.22.4` was given for extraction, the keywords
described above would resolve as follows:

+ `%tag%`: `v1.22.4`
+ `%fullname%`: `efrecon/kubectl`
+ `%shortname%`: `kubectl`
+ `%fullname_flat%`: `efrecon_kubectl`
+ `%fullyqualified_flat%`: `efrecon_kubectl_v1.22.4`
+ `%name%`: `efrecon/kubectl:v1.22.4`

### Flag `-v`

When `-v` is specified, the script will provide more verbose output on the
stderr.

### Flag `-h`

When this flag is specified, a help message will be printed out on stderr and
the script will exit. This is also the behaviour when no image name has been
provided in the list of arguments.

## GitHub Action

The script doubles as a GitHub Action, use it in a workflow as exemplified
below, provided you have access to `docker`. For a complete list of inputs and
their usage, consult the [`action.yml`](./action.yml) file.

```yaml
jobs:
  extract:
    runs-on: ubuntu-latest
    steps:
      - name: Extract
        uses: efrecon/docker-image-extract@main
        with:
          image: busybox
```
