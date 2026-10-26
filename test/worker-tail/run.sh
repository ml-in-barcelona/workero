#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-tail-test"
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}

cd "$root"
rm -rf "$out"
$dune exec workero -- build test/worker-tail/main.bc.wasm.js --out "$out"
cp test/worker-tail/tests.mjs test/worker-tail/producer.mjs test/worker-tail/sink.mjs "$out/"

modules() {
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
}

{
  echo 'using Workerd = import "/workerd/workerd.capnp";'
  echo 'const config :Workerd.Config = ('
  echo '  services = ['
  echo '    (name = "producer", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "producer.mjs", esModule = embed "producer.mjs")],'
  echo '      tails = ["trace-tail"],'
  echo '      streamingTails = ["trace-tail"],'
  echo '      durableObjectNamespaces = [(className = "Counter", uniqueKey = "counter")],'
  echo '      durableObjectStorage = (inMemory = void),'
  echo '      bindings = [(name = "COUNTER", durableObjectNamespace = "Counter")],'
  echo '    )),'
  echo '    (name = "trace-tail", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  modules
  echo '      tails = ["trace-tail-2"],'
  echo '      bindings = [(name = "SINK", service = "sink")],'
  echo '    )),'
  echo '    (name = "producer-class", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "producer.mjs", esModule = embed "producer.mjs")],'
  echo '      tails = [(name = "class-tail", entrypoint = "Tail")],'
  echo '    )),'
  echo '    (name = "class-tail", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  modules
  echo '      bindings = [(name = "SINK", service = "sink-class")],'
  echo '    )),'
  echo '    (name = "trace-tail-2", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  modules
  echo '      bindings = [(name = "SINK", service = "sink-2")],'
  echo '    )),'
  echo '    (name = "sink", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "sink.mjs", esModule = embed "sink.mjs")],'
  echo '    )),'
  echo '    (name = "sink-class", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "sink.mjs", esModule = embed "sink.mjs")],'
  echo '    )),'
  echo '    (name = "sink-2", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "sink.mjs", esModule = embed "sink.mjs")],'
  echo '    )),'
  echo '    (name = "test", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      compatibilityFlags = ["service_binding_extra_handlers"],'
  echo '      modules = [(name = "tests.mjs", esModule = embed "tests.mjs")],'
  echo '      bindings = ['
  echo '        (name = "PRODUCER", service = "producer"),'
  echo '        (name = "RPC", service = (name = "producer", entrypoint = "Svc")),'
  echo '        (name = "SINK", service = "sink"),'
  echo '        (name = "SINK_2", service = "sink-2"),'
  echo '        (name = "PRODUCER_CLASS", service = "producer-class"),'
  echo '        (name = "SINK_CLASS", service = "sink-class"),'
  echo '      ],'
  echo '    )),'
  echo '  ],'
  echo ');'
} >"$out/config.capnp"

status=0
$workerd test --experimental "$out/config.capnp" >"$out/workerd.log" 2>&1 &
workerd_pid=$!
(
  sleep "${WORKERD_TIMEOUT:-120}"
  echo "FAIL - workerd test did not finish in ${WORKERD_TIMEOUT:-120} seconds" >>"$out/workerd.log"
  kill -9 "$workerd_pid"
) >/dev/null 2>&1 &
watchdog_pid=$!
wait "$workerd_pid" || status=$?
kill "$watchdog_pid" 2>/dev/null || true
cat "$out/workerd.log"
exit $status
