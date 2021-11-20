# docker-image-extract

Extracts all layers from a Docker image to a directory, this replaces the
command that should have existed under `docker image extract`. The script will
extract all images passed as arguments to the current directory, or the
directory specified using the `-d` option. For further help, call the script
with the `-h` option.

## Requirements

This script has the following requirements:

+ Ability to run the `docker` command as the current user.
+ Minimal installation of `tar`, `grep` and `sed`, i.e. the ones from minimal
  implementations such as [busybox] will work.

  [busybox]: https://busybox.net/
