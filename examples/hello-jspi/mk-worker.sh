#!/bin/sh
# usage: mk-worker.sh <exe-name> <dest-dir>
set -e
n=$1; d=$2
mkdir -p $d
cp -rf _build/default/src/$n.bc.wasm.assets $d/
chmod -R u+w $d
node patch-loader.mjs _build/default/src/$n.bc.wasm.js $d/$n.bc.wasm.js
W=$(basename $d/$n.bc.wasm.assets/code-*.wasm)
cat > $d/index.js <<EOF
import mod from "./$n.bc.wasm.assets/$W";
globalThis.__wasm = { "$n.bc.wasm.assets/$W": mod };
await import("./$n.bc.wasm.js");
export default {
  async fetch(request) {
    await globalThis.__ready;
    const m = new URL(request.url).pathname === "/await" ? "delayed" : "run";
    return new Response((await globalThis.hello[m]()) + "\n");
  },
};
EOF
cp worker1/wrangler.toml $d/
