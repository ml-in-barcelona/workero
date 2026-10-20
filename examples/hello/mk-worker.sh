#!/bin/sh
# usage: [BUILD=_build/default] mk-worker.sh <exe-name> <dest-dir>
set -e
n=$1; d=$2; b=${BUILD:-_build/default}
mkdir -p $d
cp -rf $b/src/$n.bc.wasm.assets $b/src/$n.bc.wasm.js load-wasm.js $d/
chmod -R u+w $d
{
  i=0; map=
  for f in $d/$n.bc.wasm.assets/*.wasm; do
    p=$n.bc.wasm.assets/$(basename $f)
    echo "import m$i from \"./$p\";"
    map="$map \"$p\": m$i,"
    i=$((i+1))
  done
  cat <<JS
import { loadWasmOCaml } from "./load-wasm.js";
await loadWasmOCaml({$map }, () => import("./$n.bc.wasm.js"));
export default {
  async fetch(request) {
    const routes = { "/await": "delayed", "/fail": "failing" };
    const method = routes[new URL(request.url).pathname] ?? "run";
    try {
      return new Response((await globalThis.hello[method]()) + "\n");
    } catch (error) {
      return new Response("error: " + error + "\n", { status: 500 });
    }
  },
};
JS
} > $d/index.js
cp worker1/wrangler.toml $d/
