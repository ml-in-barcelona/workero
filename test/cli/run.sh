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

workero test/cli/present/main || fail "a worker without missing primitives builds"
[ -f "$out/index.js" ] || fail "index.js is written"
echo "ok - a worker without missing primitives builds"

for fixture in missing missing-pretty; do
for run in first second; do
  if workero test/cli/$fixture/main; then fail "$fixture: missing primitives fail the build ($run run)"; fi
  grep -q "workero: main uses functions with no wasm implementation: workero_test_missing_one, workero_test_missing_two" "$log" ||
    fail "$fixture: the error lists the primitives ($run run)"
  grep -q "wasm_files" "$log" && grep -q -- "--allow-missing-primitives" "$log" ||
    fail "$fixture: the error hints at a fix ($run run)"
  echo "ok - $fixture: missing primitives fail the build ($run run)"
done
done

for fixture in missing missing-pretty; do
  rm -rf "$out"
  workero test/cli/$fixture/main --allow-missing-primitives ||
    fail "$fixture: --allow-missing-primitives builds"
  grep -q "workero: warning: main uses functions with no wasm implementation: workero_test_missing_one, workero_test_missing_two" "$log" ||
    fail "$fixture: the warning lists the primitives"
  [ -f "$out/index.js" ] || fail "$fixture: the worker is written with the flag"
  echo "ok - $fixture: --allow-missing-primitives warns and writes the worker"
done
