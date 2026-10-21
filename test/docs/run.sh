#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}
mkdir -p "$root/_build"
out=$(mktemp -d "$root/_build/doc-tests.XXXXXX")
scratch=${DOC_TEST_TMPDIR:-${TMPDIR:-/tmp}}
if [ -d /tmp/opencode ] && [ -z "${DOC_TEST_TMPDIR:-}" ]; then scratch=/tmp/opencode; fi
external=$(mktemp -d "$scratch/workero-docs.XXXXXX")
trap 'rm -rf "$external"' EXIT HUP INT TERM
prefix="$out/install"
projects="$external/projects"
mkdir -p "$projects"

echo "Doc test logs and packages: $out"
cd "$root"
$dune build @install >"$out/install-build.log" 2>&1 || {
  cat "$out/install-build.log"
  exit 1
}
$dune install --prefix "$prefix" >"$out/install.log" 2>&1 || {
  cat "$out/install.log"
  exit 1
}
export OCAMLPATH="$prefix/lib${OCAMLPATH:+:$OCAMLPATH}"
export PATH="$prefix/bin:$PATH"
node "$root/test/docs/extract.mjs" "$root" "$projects" >"$out/extract.log" 2>&1 || {
  cat "$out/extract.log"
  exit 1
}
cat "$out/extract.log"
cp "$projects/manifest.json" "$out/manifest.json"
for project in "$projects"/*; do
  [ -d "$project" ] || continue
  name=$(basename "$project")
  echo "Compile $name"
  (unset DUNE_ROOT DUNE_BUILD_DIR; cd "$project" && $dune build --profile release src/main.bc.wasm.js) >"$out/$name.log" 2>&1 || {
    cat "$out/$name.log"
    exit 1
  }
done

cp -R "$root/template" "$external/template"
for spec in README:README-1 TEMPLATE:template REQUESTS:requests-1 STREAMS:streams-1 FORMS:forms-1 JSON:json-1 CACHE:cache-1; do
  name=${spec%%:*}
  project=${spec#*:}
  dir="$projects/$project"
  if [ "$project" = template ]; then dir="$external/template"; fi
  (unset DUNE_ROOT DUNE_BUILD_DIR; cd "$dir"
    if [ "$project" = template ]; then
      opam exec -- "$prefix/bin/workero" build src/main.bc.wasm.js --out "$out/$name"
    else
      "$prefix/bin/workero" package _build/default/src/main.bc.wasm.js --out "$out/$name"
    fi
  ) >"$out/package-$name.log" 2>&1 || {
    cat "$out/package-$name.log"
    exit 1
  }
done
cp "$root/test/docs/tests.mjs" "$root/test/docs/upstream.mjs" "$out/"
cp "$root/test/worker/services/cache.mjs" "$out/cache.mjs"
node "$root/test/docs/config.mjs" "$out"
if ! "$workerd" test "$out/config.capnp" >"$out/workerd.log" 2>&1; then
  cat "$out/workerd.log"
  exit 1
fi
cat "$out/workerd.log"
