#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

packages=workerd,workerd-linux-64,workerd-linux-arm64,workerd-darwin-64,workerd-darwin-arm64,wrangler

plan=$(node scripts/upstream.ts)
if [ -z "$plan" ]; then
  echo "No new upstream version." >&2
  exit 0
fi

while read -r name version; do
  echo "Release $name $version" >&2
  node "scripts/$name-opam.ts" "$version" >&2
  node scripts/changelog.ts "$name" "$version" "- Update to $name $version."
  opam exec -- dune build @install --only-packages "$packages" --auto-promote >&2 ||
    opam exec -- dune build @install --only-packages "$packages" >&2
  opam lint ./*.opam >&2
  git add -- '*.opam' '*.opam.template' "CHANGES-$name.md"
  if ! git diff --cached --quiet; then
    git commit -q -m "Release $name $version" >&2
  fi
  git tag "$name-$version"
  echo "$name-$version"
done <<EOT
$plan
EOT
