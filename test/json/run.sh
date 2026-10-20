#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-json-test"
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}

cd "$root"
$dune exec workero -- build test/json/main --out "$out"
cp test/json/tests.mjs "$out/tests.mjs"

{
  echo 'using Workerd = import "/workerd/workerd.capnp";'
  echo 'const config :Workerd.Config = ('
  echo '  services = ['
  echo '    (name = "worker", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = ['
  (cd "$out" && find . -type f -name '*.js' ! -name 'tests.mjs' | sed 's|^\./||' | sort) |
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

exec $workerd test "$out/config.capnp"
