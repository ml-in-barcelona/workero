#!/bin/sh
set -eu

if [ $# -ne 1 ] && [ $# -ne 3 ]; then
  echo "Usage: $0 <file.opam> [<archive url> <sha512>]" >&2
  exit 2
fi

grep -v '^version:' "$1"
if [ $# -eq 3 ]; then
  printf 'url {\n  src: "%s"\n  checksum: "sha512=%s"\n}\n' "$2" "$3"
fi
