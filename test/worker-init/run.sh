#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-init-test"
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}

cd "$root"
$dune exec workero -- build test/worker-init/main --out "$out"
cp test/worker-init/tests.mjs "$out/"

{
  echo 'using Workerd = import "/workerd/workerd.capnp";'
  echo 'const config :Workerd.Config = ('
  echo '  services = ['
  echo '    (name = "worker", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = ['
  (cd "$out" && find . -type f -name '*.js' | sed 's|^\./||' | sort) |
    while read -r f; do
      echo "        (name = \"$f\", esModule = embed \"$f\"),"
    done
  (cd "$out" && find . -type f -name '*.wasm' | sed 's|^\./||' | sort) |
    while read -r f; do
      echo "        (name = \"$f\", wasm = embed \"$f\"),"
    done
  echo '      ],'
  echo '    )),'
  echo '    (name = "test", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "tests.mjs", esModule = embed "tests.mjs")],'
  echo '      bindings = [(name = "WORKER", service = "worker")],'
  echo '    )),'
  echo '  ],'
  echo ');'
} >"$out/config.capnp"

log="$out/workerd.log"
if $workerd test "$out/config.capnp" >"$log" 2>&1; then
  cat "$log"
  echo "FAIL - the worker loaded although OCaml initialisation raised"
  exit 1
fi
detail=$(grep -A2 "Uncaught .*(exit code 2):$" "$log" | tail -n +2)
expected='context before the failure
Fatal error: exception Failure("boom at init")'
if [ "$detail" != "$expected" ]; then
  cat "$log"
  echo "FAIL - the load error lacks the exit code or the newline-separated stderr lines"
  exit 1
fi
echo "ok - an OCaml exception at init fails the load with its message"
