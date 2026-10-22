#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

name=${1:?Usage: $0 <workerd|wrangler>}

version=$(node scripts/upstream.ts "$name" --tagged)
if [ -z "$version" ]; then
  exit 0
fi
tag="$name-$version"
active=$(gh run list --workflow release-binaries.yml --branch "$tag" --json status,conclusion \
  --jq '[.[] | select(.status != "completed" or .conclusion == "success")] | length')
if [ "$active" = 0 ]; then
  echo "Restart the release of $tag" >&2
  gh workflow run release-binaries.yml --ref "$tag" -f tag="$tag"
fi
