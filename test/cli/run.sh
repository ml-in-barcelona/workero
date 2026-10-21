#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-cli-test"
dune=${DUNE:-dune}
log=$(mktemp)
trap 'rm -f "$log"' EXIT

cd "$root"
$dune build bin/main.exe

fail() {
  echo "FAIL - $1"
  cat "$log"
  exit 1
}

workero() { $dune exec workero -- build "$@" --out "$out" >"$log" 2>&1; }

workero test/cli/present/main.bc.wasm.js || fail "a worker without missing primitives builds"
[ -f "$out/index.js" ] || fail "index.js is written"
echo "ok - a worker without missing primitives builds"

rm -rf "$out"
$dune exec workero -- package _build/default/test/cli/present/main.bc.wasm.js --out "$out" >"$log" 2>&1 ||
  fail "package writes a worker from built output"
for f in index.js load-wasm.js main.bc.wasm.js main.bc.wasm.assets; do
  [ -e "$out/$f" ] || fail "package writes $f"
done
echo "ok - package writes a worker from built output"

if $dune exec workero -- package _build/default/test/cli/nope/main.bc.wasm.js --out "$out" >"$log" 2>&1; then
  fail "package fails when the output is missing"
fi
grep -q "workero: loader not found" "$log" || fail "package reports the missing loader"
echo "ok - package fails when the output is missing"

wasm_count() { find "$out/main.bc.wasm.assets" -name '*.wasm' | wc -l; }

rm -rf "$out"
workero test/cli/present/main.bc.wasm.js || fail "build adds the release profile"
[ "$(wasm_count)" -eq 1 ] || fail "the default build uses the release profile (one wasm file)"
echo "ok - build adds the release profile"

rm -rf "$out"
workero test/cli/present/main.bc.wasm.js --profile dev --display quiet --allow-missing-primitives ||
  fail "build passes dune arguments"
[ "$(wasm_count)" -gt 1 ] || fail "--profile dev reaches dune (more than one wasm file)"
echo "ok - build passes dune arguments"

rm -rf "$out"
workero --profile dev test/cli/present/main.bc.wasm.js --out="$out" ||
  fail "build accepts --out=<dir> and arguments before the target"
[ -f "$out/index.js" ] || fail "--out=<dir> sets the output directory"
echo "ok - build accepts --out=<dir> and arguments before the target"

if workero --profile dev; then fail "build without a .bc.wasm.js target fails"; fi
grep -q "^workero: usage: workero build" "$log" || fail "build without a target prints the usage"
echo "ok - build without a .bc.wasm.js target is a usage error"

if workero test/cli/present/main.bc.wasm.js test/cli/missing/main.bc.wasm.js; then
  fail "build with two targets fails"
fi
grep -q "^workero: usage: workero build" "$log" || fail "build with two targets prints the usage"
echo "ok - build with two .bc.wasm.js targets is a usage error"

if $dune exec workero -- package _build/default/test/cli/present/main --out "$out" >"$log" 2>&1; then
  fail "package fails without .bc.wasm.js"
fi
grep -q "workero: usage: workero build" "$log" || fail "package without .bc.wasm.js prints the usage"
echo "ok - package with a path that is not a .bc.wasm.js is a usage error"

for fixture in missing missing-pretty; do
for run in first second; do
  if workero test/cli/$fixture/main.bc.wasm.js; then fail "$fixture: missing primitives fail the build ($run run)"; fi
  grep -q "workero: main uses functions with no wasm implementation: workero_test_missing_one, workero_test_missing_two" "$log" ||
    fail "$fixture: the error lists the primitives ($run run)"
  grep -q "wasm_files" "$log" && grep -q -- "--allow-missing-primitives" "$log" ||
    fail "$fixture: the error hints at a fix ($run run)"
  echo "ok - $fixture: missing primitives fail the build ($run run)"
done
done

for fixture in missing missing-pretty; do
  rm -rf "$out"
  workero test/cli/$fixture/main.bc.wasm.js --allow-missing-primitives ||
    fail "$fixture: --allow-missing-primitives builds"
  grep -q "workero: warning: main uses functions with no wasm implementation: workero_test_missing_one, workero_test_missing_two" "$log" ||
    fail "$fixture: the warning lists the primitives"
  [ -f "$out/index.js" ] || fail "$fixture: the worker is written with the flag"
  echo "ok - $fixture: --allow-missing-primitives warns and writes the worker"
done
