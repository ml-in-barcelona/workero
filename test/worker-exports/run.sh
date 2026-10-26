#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}

cd "$root"

config() {
  out=$1
  expect=$2
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
    echo '    (name = "probe", worker = ('
    echo '      compatibilityDate = "2026-10-01",'
    echo '      modules = ['
    echo '        (name = "probe.mjs", esModule = embed "probe.mjs"),'
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
    echo '      compatibilityFlags = ["service_binding_extra_handlers"],'
    echo '      modules = [(name = "tests.mjs", esModule = embed "tests.mjs")],'
    echo "      bindings = [(name = \"WORKER\", service = \"worker\"), (name = \"PROBE\", service = \"probe\"), (name = \"EXPECT\", text = \"$expect\")],"
    echo '    )),'
    echo '  ],'
    echo ');'
  } >"$out/config.capnp"
}

check() {
  name=$1
  expect=$2
  out="$root/_worker-exports-test/$name"
  log="$out.log"
  rm -rf "$out"
  mkdir -p "$out"
  $dune exec workero -- build "test/worker-exports/$name/main.bc.wasm.js" --out "$out" >/dev/null
  cp test/worker-exports/tests.mjs test/worker-exports/probe.mjs "$out/"
  config "$out" "$expect"
  if [ "$expect" = none ]; then
    if $workerd test --experimental "$out/config.capnp" >"$log" 2>&1; then
      cat "$log"
      echo "FAIL - $name: the worker loaded with no handler"
      exit 1
    fi
    grep -q "registered no handler" "$log" || {
      cat "$log"
      echo "FAIL - $name: the load error lacks the no handler message"
      exit 1
    }
    echo "ok - $name: the load fails with the no handler message"
  else
    $workerd test --experimental "$out/config.capnp" >"$log" 2>&1 || {
      cat "$log"
      echo "FAIL - $name"
      exit 1
    }
    grep "^ok - exports" "$log" | sed "s/^ok - /ok - $name: /"
  fi
}

check serve fetch
check scheduled scheduled
check both fetch+scheduled
check queue queue
check email email
check tail tail
check tail_stream tailStream
check none none
check workflow ""
