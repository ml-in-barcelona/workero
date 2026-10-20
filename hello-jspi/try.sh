#!/bin/sh
# usage: try.sh <worker-dir> [paths...]
export OPAMROOT=/home/me/workplace/davesnx/workero/hello/.opam-root OPAMSWITCH=hello55 OPAMNODEPEXTS=1
eval $(opam env --switch=hello55 --root=$OPAMROOT 2>/dev/null)
export PATH=/home/me/workplace/davesnx/workero/hello/node_modules/.bin:$PATH
R=$(cd "$(dirname "$0")" && pwd)
export WRANGLER_LOG_PATH=$R/.wrangler-logs XDG_CONFIG_HOME=$R/.config WRANGLER_SEND_METRICS=false
d=$1; shift
cd $R/$d
timeout 40 wrangler dev --local --port 8788 > $R/$d.log 2>&1 &
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do sleep 2; curl -s -m3 -o /dev/null localhost:8788 && break; done
for p in "$@"; do echo "GET $p"; curl -s -w "HTTP %{http_code}\n" localhost:8788$p; done
wait
