#!/bin/sh
# usage: [N=50] [PORT=8787] [WRANGLER=wrangler] example/bench.sh
set -e
cd "$(dirname "$0")/.."
n=${N:-50}; port=${PORT:-8787}; wrangler=${WRANGLER:-wrangler}
tmp=$(mktemp -d)
trap 'kill $pid 2>/dev/null; rm -rf $tmp' EXIT

dune exec workero -- build example/main

echo "== files in _worker/ (bytes raw, gzip)"
total_raw=0; total_gz=0
for f in $(find _worker -type f | sort); do
  raw=$(wc -c < $f); gz=$(gzip -9 -c $f | wc -c)
  printf '%10d %10d  %s\n' $raw $gz $f
  total_raw=$((total_raw + raw)); total_gz=$((total_gz + gz))
done
printf '%10d %10d  total\n' $total_raw $total_gz

echo "== wrangler deploy --dry-run (limits: 3 MiB free, 10 MiB paid, gzip)"
(cd example && $wrangler deploy --dry-run --outdir $tmp/out 2>&1 | grep -i "upload")

echo "== wrangler dev --local, $n warm requests"
(cd example && exec $wrangler dev --local --port $port > $tmp/dev.log 2>&1) &
pid=$!
url=http://localhost:$port/
i=0
until grep -q "Ready on" $tmp/dev.log; do
  i=$((i + 1)); [ $i -gt 150 ] && { cat $tmp/dev.log; exit 1; }
  sleep 0.2
done

t='%{time_starttransfer} %{time_total}\n'
curl -s -o /dev/null -w "$t" $url > $tmp/cold
i=0
while [ $i -lt $n ]; do
  curl -s -o /dev/null -w "$t" $url >> $tmp/warm
  i=$((i + 1))
done
printf 'cold  ttfb %.1f ms  total %.1f ms\n' \
  $(awk '{print $1*1000, $2*1000}' $tmp/cold)
for col in 1 2; do
  sort -n -k$col $tmp/warm | awk -v c=$col -v n=$n '
    { v[NR] = $c * 1000 }
    END { printf "warm  %-5s min %.1f  median %.1f  p95 %.1f  max %.1f ms\n",
      (c == 1 ? "ttfb" : "total"), v[1], v[int((n + 1) / 2)], v[int(n * 0.95 + 0.5)], v[n] }'
done

echo "== GET /"
curl -s $url
