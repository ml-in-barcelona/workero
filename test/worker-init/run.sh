#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-init-test"
dune=${DUNE:-dune}
log=$(mktemp)
trap 'rm -f "$log"' EXIT

cd "$root"
if $dune exec workero -- build test/worker-init/main.bc.wasm.js --out "$out" >"$log" 2>&1; then
  cat "$log"
  echo "FAIL - the build succeeded although OCaml initialisation raised"
  exit 1
fi
detail=$(grep -A2 "Uncaught .*(exit code 2):$" "$log" | tail -n +2)
expected='context before the failure
Fatal error: exception Failure("boom at init")'
if [ "$detail" != "$expected" ]; then
  cat "$log"
  echo "FAIL - the build error lacks the exit code or the newline-separated stderr lines"
  exit 1
fi
grep -q "^workero: the program failed to initialise in workerd" "$log" || {
  cat "$log"
  echo "FAIL - the build error does not say that initialisation failed"
  exit 1
}
echo "ok - an OCaml exception at init fails the build with its message"
