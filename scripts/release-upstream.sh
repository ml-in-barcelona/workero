#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

name=${1:?Usage: $0 <workerd|wrangler>}

version=$(node scripts/upstream.ts "$name")
if [ -z "$version" ]; then
  echo "No new $name version." >&2
  exit 0
fi

echo "Release $name $version" >&2
node "scripts/$name-opam.ts" "$version" >&2
node scripts/changelog.ts "$name" "$version" "- Update to $name $version."
opam exec -- dune build @install --only-packages workerd,wrangler --auto-promote >&2 ||
  opam exec -- dune build @install --only-packages workerd,wrangler >&2
opam lint ./*.opam >&2
git add -- '*.opam' '*.opam.template' "CHANGES-$name.md"
if ! git diff --cached --quiet; then
  git commit -q -m "Release $name $version" >&2
fi
git tag "$name-$version"
echo "$name-$version"
