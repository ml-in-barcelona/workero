#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

node scripts/upstream.ts --tagged | while read -r name version; do
  tag="$name-$version"
  active=$(gh run list --workflow release-binaries.yml --branch "$tag" --json status,conclusion \
    --jq '[.[] | select(.status != "completed" or .conclusion == "success")] | length' </dev/null)
  if [ "$active" = 0 ]; then
    echo "Restart the release of $tag" >&2
    gh workflow run release-binaries.yml --ref "$tag" -f tag="$tag" </dev/null
  fi
done
