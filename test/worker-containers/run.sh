#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-containers-test"
dune=${DUNE:-dune}
workerd=${WORKERD:-workerd}
app_image=alpine:3.22
proxy_image=cloudflare/proxy-everything:510e5ce

skip() {
  if [ "${WORKERO_REQUIRE_CONTAINERS:-}" = 1 ]; then
    echo "FAIL containers: $1 (WORKERO_REQUIRE_CONTAINERS=1)"
    exit 1
  fi
  echo "SKIP containers: $1"
  exit 0
}

command -v docker >/dev/null 2>&1 || skip "docker is not installed"
docker info >/dev/null 2>&1 || skip "the Docker daemon is not usable"
for image in "$app_image" "$proxy_image"; do
  docker image inspect "$image" >/dev/null 2>&1 || skip "the image $image is not present; run docker pull $image"
done

cd "$root"
$dune exec workero -- build test/worker-containers/main.bc.wasm.js --out "$out"
rm -rf "$out/do-data"
mkdir -p "$out/do-data"
cp test/worker-containers/tests.mjs "$out/"

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
  echo '      bindings = [(name = "SANDBOX", durableObjectNamespace = "Sandbox")],'
  echo "      durableObjectNamespaces = [(className = \"Sandbox\", uniqueKey = \"workero-test-Sandbox\", enableSql = true, container = (imageName = \"$app_image\"))],"
  echo '      durableObjectStorage = (localDisk = "do-disk"),'
  echo "      containerEngine = (localDocker = (socketPath = \"unix:/var/run/docker.sock\", containerEgressInterceptorImage = \"$proxy_image\")),"
  echo '    )),'
  echo "    (name = \"do-disk\", disk = (path = \"$out/do-data\", writable = true)),"
  echo '    (name = "test", worker = ('
  echo '      compatibilityDate = "2026-10-01",'
  echo '      modules = [(name = "tests.mjs", esModule = embed "tests.mjs")],'
  echo '      bindings = [(name = "WORKER", service = "worker")],'
  echo '    )),'
  echo '  ],'
  echo ');'
} >"$out/config.capnp"

status=0
$workerd test --experimental "$out/config.capnp" >"$out/workerd.log" 2>&1 &
workerd_pid=$!
(
  sleep "${WORKERD_TIMEOUT:-240}"
  echo "FAIL - workerd test did not finish in ${WORKERD_TIMEOUT:-240} seconds" >>"$out/workerd.log"
  kill -9 "$workerd_pid"
) >/dev/null 2>&1 &
watchdog_pid=$!
wait "$workerd_pid" || status=$?
kill "$watchdog_pid" 2>/dev/null || true
cat "$out/workerd.log"
exit $status
