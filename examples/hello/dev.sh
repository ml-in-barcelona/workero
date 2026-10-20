#!/bin/sh
cd "$(dirname "$0")/$1"
export WRANGLER_LOG_PATH=$PWD/../.wrangler-logs XDG_CONFIG_HOME=$PWD/../.config WRANGLER_SEND_METRICS=false
pkill -f "wrangler dev"; pkill -f workerd; sleep 1
../node_modules/.bin/wrangler dev --local --port 8787 > ../$1.log 2>&1 &
sleep ${2:-10}
