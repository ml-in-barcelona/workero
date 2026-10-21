#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-test"
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}

cd "$root"
$dune exec workero -- build test/worker/main.bc.wasm.js --out "$out"
rm -rf "$out/d1-data" "$out/do-data"
mkdir -p "$out/d1-data" "$out/do-data"
cp test/worker/tests.mjs test/worker/tests_queue.mjs test/worker/upstream.mjs test/worker/services/*.mjs "$out/"
rm -rf "$out/cases"
mkdir -p "$out/cases"
cp test/worker/cases/*.mjs "$out/cases/"

{
  echo 'using Workerd = import "/workerd/workerd.capnp";'
  echo 'const config :Workerd.Config = ('
  echo '  services = ['
  echo '    (name = "worker", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = ['
  (echo index.js; cd "$out" && find . -type f -name '*.js' | sed 's|^\./||' | grep -vx index.js | sort) |
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
  echo '        (name = "API_TOKEN", text = "tok-123"),'
  printf '%s\n' '        (name = "SETTINGS", json = "{\"foo\":42,\"nested\":{\"list\":[1,2]},\"name\":\"x\"}"),'
  printf '%s\n' '        (name = "LIMITS", json = "[1,\"two\",null]"),'
  echo '        (name = "BACKEND", service = "backend"),'
  for class in Counter Alarms NoFetch Awaiting class; do
    echo "        (name = \"$(echo "$class" | tr a-z A-Z)\", durableObjectNamespace = \"$class\"),"
  done
  echo '        (name = "KV", kvNamespace = "kv"),'
  echo '        (name = "BUCKET", r2Bucket = "r2"),'
  echo '        (name = "DB", wrapped = ('
  echo '          moduleName = "workero-test:d1",'
  echo '          innerBindings = [(name = "DATABASE", service = (name = "d1", entrypoint = "D1"))],'
  echo '        )),'
  echo '        (name = "STORE", wrapped = (moduleName = "workero-test:secret-store", innerBindings = [(name = "VALUE", text = "store-value")])),'
  echo '        (name = "STORE_NULL", wrapped = (moduleName = "workero-test:secret-store", innerBindings = [(name = "MODE", text = "null")])),'
  echo '        (name = "STORE_UNDEFINED", wrapped = (moduleName = "workero-test:secret-store", innerBindings = [(name = "MODE", text = "undefined")])),'
  echo '        (name = "STORE_BROKEN", wrapped = (moduleName = "workero-test:secret-store", innerBindings = [(name = "MODE", text = "fail")])),'
  echo '        (name = "JOBS", queue = "queue-sink"),'
  echo '        (name = "LIMITER", wrapped = (moduleName = "workero-test:forward", innerBindings = [(name = "METHODS", text = "limit"), (name = "TARGET", service = (name = "limiter", entrypoint = "Limiter"))])),'
  echo '        (name = "AI", wrapped = (moduleName = "workero-test:forward", innerBindings = [(name = "METHODS", text = "run"), (name = "TARGET", service = (name = "ai", entrypoint = "Ai"))])),'
  echo '        (name = "ANALYTICS", wrapped = (moduleName = "workero-test:analytics", innerBindings = [])),'
  echo '        (name = "ANALYTICS_BROKEN", wrapped = (moduleName = "workero-test:analytics-broken", innerBindings = [])),'
  echo '      ],'
  echo '      durableObjectNamespaces = ['
  for class in Counter Alarms NoFetch Awaiting class; do
    echo "        (className = \"$class\", uniqueKey = \"workero-test-$class\", enableSql = true),"
  done
  echo '      ],'
  echo '      durableObjectStorage = (localDisk = "do-disk"),'
  echo '      globalOutbound = "upstream",'
  echo '      cacheApiOutbound = "cache",'
  echo '    )),'
  echo '    (name = "upstream", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "upstream.mjs", esModule = embed "upstream.mjs")],'
  echo '    )),'
  for svc in kv r2 cache backend queue-sink limiter ai; do
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
  echo "    (name = \"do-disk\", disk = (path = \"$out/do-data\", writable = true)),"
  echo '    (name = "test", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = ['
  echo '        (name = "tests.mjs", esModule = embed "tests.mjs"),'
  for f in $(cd "$out" && ls cases/*.mjs); do
    echo "        (name = \"$f\", esModule = embed \"$f\"),"
  done
  echo '      ],'
  echo '      bindings = [(name = "WORKER", service = "worker")],'
  echo '    )),'
  echo '    (name = "test-queue", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      compatibilityFlags = ["service_binding_extra_handlers"],'
  echo '      modules = ['
  echo '        (name = "tests_queue.mjs", esModule = embed "tests_queue.mjs"),'
  echo '        (name = "cases/queue.mjs", esModule = embed "cases/queue.mjs"),'
  echo '        (name = "cases/lib.mjs", esModule = embed "cases/lib.mjs"),'
  echo '      ],'
  echo '      bindings = [(name = "WORKER", service = "worker"), (name = "SINK", service = "queue-sink")],'
  echo '    )),'
  echo '  ],'
  echo '  extensions = ['
  echo '    (modules = [(name = "workero-test:d1", internal = true, esModule = embed "d1-binding.mjs")]),'
  echo '    (modules = [(name = "workero-test:secret-store", internal = true, esModule = embed "secret-store-binding.mjs")]),'
  echo '    (modules = [(name = "workero-test:forward", internal = true, esModule = embed "forward-binding.mjs")]),'
  echo '    (modules = [(name = "workero-test:analytics", internal = true, esModule = embed "analytics-binding.mjs")]),'
  echo '    (modules = [(name = "workero-test:analytics-broken", internal = true, esModule = embed "analytics-broken-binding.mjs")]),'
  echo '  ],'
  echo ');'
} >"$out/config.capnp"

status=0
$workerd test --experimental "$out/config.capnp" >"$out/workerd.log" 2>&1 || status=$?
cat "$out/workerd.log"
for marker in log-marker-unflushed log-marker-raise; do
  grep -q "$marker" "$out/workerd.log" || {
    echo "FAIL - $marker is not in the workerd log"
    status=1
  }
done
exit $status
