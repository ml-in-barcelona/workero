#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-test"
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}

cd "$root"
$dune exec workero -- build test/worker/main --out "$out"
rm -rf "$out/d1-data"
mkdir -p "$out/d1-data"
cp test/worker/tests.mjs test/worker/upstream.mjs test/worker/services/*.mjs "$out/"

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
  echo '      bindings = ['
  echo '        (name = "GREETING", text = "from test config"),'
  echo '        (name = "KV", kvNamespace = "kv"),'
  echo '        (name = "BUCKET", r2Bucket = "r2"),'
  echo '        (name = "DB", wrapped = ('
  echo '          moduleName = "workero-test:d1",'
  echo '          innerBindings = [(name = "DATABASE", service = (name = "d1", entrypoint = "D1"))],'
  echo '        )),'
  echo '      ],'
  echo '      globalOutbound = "upstream",'
  echo '      cacheApiOutbound = "cache",'
  echo '    )),'
  echo '    (name = "upstream", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "upstream.mjs", esModule = embed "upstream.mjs")],'
  echo '    )),'
  for svc in kv r2 cache; do
    echo "    (name = \"$svc\", worker = ("
    echo '      compatibilityDate = "2026-10-01",'
    echo "      modules = [(name = \"$svc.mjs\", esModule = embed \"$svc.mjs\")],"
    echo '    )),'
  done
  echo '    (name = "d1", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "d1.mjs", esModule = embed "d1.mjs")],'
  echo '      bindings = [(name = "DATABASE", durableObjectNamespace = "Database")],'
  echo '      durableObjectNamespaces = [(className = "Database", uniqueKey = "d1-test", enableSql = true)],'
  echo '      durableObjectStorage = (localDisk = "d1-disk"),'
  echo '    )),'
  echo "    (name = \"d1-disk\", disk = (path = \"$out/d1-data\", writable = true)),"
  echo '    (name = "test", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "tests.mjs", esModule = embed "tests.mjs")],'
  echo '      bindings = [(name = "WORKER", service = "worker")],'
  echo '    )),'
  echo '  ],'
  echo '  extensions = ['
  echo '    (modules = [(name = "workero-test:d1", internal = true, esModule = embed "d1-binding.mjs")]),'
  echo '  ],'
  echo ');'
} >"$out/config.capnp"

exec $workerd test "$out/config.capnp"
