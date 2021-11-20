# docker-image-extract

Extracts all layers from a Docker image to a directory, this replaces the
command that should have existed under `docker image extract`. The script will
extract all images passed as arguments to the current directory, or the
directory specified using the `-t` option. For further help, call the script
with the `-h` option. Images are automatically been pulled if they do not exist
at the host. When pulling was necessary, images will be removed once all their
layers have been extracted.

## Requirements

This script has the following requirements:

+ Ability to run the `docker` command as the current user.
+ Minimal installation of `tar`, `grep` and `sed`, i.e. the ones from minimal
  implementations such as [busybox] will work.

  [busybox]: https://busybox.net/

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
