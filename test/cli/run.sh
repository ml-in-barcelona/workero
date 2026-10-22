#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/_worker-cli-test"
dune=${DUNE:-dune}
log=$(mktemp)
trap 'rm -f "$log"' EXIT

cd "$root"
$dune build bin/main.exe

fail() {
  echo "FAIL - $1"
  cat "$log"
  exit 1
}

workero() { $dune exec workero -- build "$@" --out "$out" >"$log" 2>&1; }

workero test/cli/present/main.bc.wasm.js || fail "a worker without missing primitives builds"
[ -f "$out/index.js" ] || fail "index.js is written"
echo "ok - a worker without missing primitives builds"

rm -rf "$out"
$dune exec workero -- package _build/default/test/cli/present/main.bc.wasm.js --out "$out" >"$log" 2>&1 ||
  fail "package writes a worker from built output"
for f in index.js load-wasm.js main.bc.wasm.js main.bc.wasm.assets; do
  [ -e "$out/$f" ] || fail "package writes $f"
done
echo "ok - package writes a worker from built output"

if $dune exec workero -- package _build/default/test/cli/nope/main.bc.wasm.js --out "$out" >"$log" 2>&1; then
  fail "package fails when the output is missing"
fi
grep -q "workero: loader not found" "$log" || fail "package reports the missing loader"
echo "ok - package fails when the output is missing"

wasm_count() { find "$out/main.bc.wasm.assets" -name '*.wasm' | wc -l; }

rm -rf "$out"
workero test/cli/present/main.bc.wasm.js || fail "build adds the release profile"
[ "$(wasm_count)" -eq 1 ] || fail "the default build uses the release profile (one wasm file)"
echo "ok - build adds the release profile"

rm -rf "$out"
workero test/cli/present/main.bc.wasm.js --profile dev --display quiet --allow-missing-primitives ||
  fail "build passes dune arguments"
[ "$(wasm_count)" -gt 1 ] || fail "--profile dev reaches dune (more than one wasm file)"
echo "ok - build passes dune arguments"

rm -rf "$out"
workero --profile dev test/cli/present/main.bc.wasm.js --out="$out" ||
  fail "build accepts --out=<dir> and arguments before the target"
[ -f "$out/index.js" ] || fail "--out=<dir> sets the output directory"
echo "ok - build accepts --out=<dir> and arguments before the target"

if workero --profile dev; then fail "build without a .bc.wasm.js target fails"; fi
grep -q "^workero: usage: workero build" "$log" || fail "build without a target prints the usage"
echo "ok - build without a .bc.wasm.js target is a usage error"

if workero test/cli/present/main.bc.wasm.js test/cli/missing/main.bc.wasm.js; then
  fail "build with two targets fails"
fi
grep -q "^workero: usage: workero build" "$log" || fail "build with two targets prints the usage"
echo "ok - build with two .bc.wasm.js targets is a usage error"

if $dune exec workero -- package _build/default/test/cli/present/main --out "$out" >"$log" 2>&1; then
  fail "package fails without .bc.wasm.js"
fi
grep -q "workero: usage: workero build" "$log" || fail "package without .bc.wasm.js prints the usage"
echo "ok - package with a path that is not a .bc.wasm.js is a usage error"

for fixture in missing missing-pretty; do
for run in first second; do
  if workero test/cli/$fixture/main.bc.wasm.js; then fail "$fixture: missing primitives fail the build ($run run)"; fi
  grep -q "workero: main uses functions with no wasm implementation: workero_test_missing_one, workero_test_missing_two" "$log" ||
    fail "$fixture: the error lists the primitives ($run run)"
  grep -q "wasm_files" "$log" && grep -q -- "--allow-missing-primitives" "$log" ||
    fail "$fixture: the error hints at a fix ($run run)"
  echo "ok - $fixture: missing primitives fail the build ($run run)"
done
done

for fixture in missing missing-pretty; do
  rm -rf "$out"
  workero test/cli/$fixture/main.bc.wasm.js --allow-missing-primitives ||
    fail "$fixture: --allow-missing-primitives builds"
  grep -q "workero: warning: main uses functions with no wasm implementation: workero_test_missing_one, workero_test_missing_two" "$log" ||
    fail "$fixture: the warning lists the primitives"
  [ -f "$out/index.js" ] || fail "$fixture: the worker is written with the flag"
  echo "ok - $fixture: --allow-missing-primitives warns and writes the worker"
done

rm -rf "$out"
workero test/cli/durable-objects/main.bc.wasm.js || fail "a program with Durable Object classes builds"
grep -q "workero: Durable Object classes: Alpha, Beta, Error, WorkeroDurableObject, class" "$log" || fail "build lists the Durable Object classes"
[ -f "$out/durable-object.js" ] || fail "durable-object.js is written when a class is registered"
for class in Alpha Beta class WorkeroDurableObject Error; do
  grep -q "^export { workero_class_[0-9]* as $class };" "$out/index.js" ||
    fail "index.js exports the class $class"
done
for probe in workero-probe.mjs workero-probe.capnp workero-probe.log; do
  [ ! -e "$out/$probe" ] || fail "build removes $probe"
done
echo "ok - build exports the registered Durable Object classes"

grep -q 'prototype\[m\] = function' "$out/index.js" || fail "index.js adds the RPC methods of a class"
[ "$(grep -c 'for (const m of' "$out/index.js")" -eq 1 ] || fail "only the class with RPC methods gets RPC glue"
grep -q 'for (const m of \["increment", "get"\]) workero_class_[0-9]*.prototype' "$out/index.js" ||
  fail "index.js lists the RPC methods in declaration order"
echo "ok - build adds the declared RPC methods to the class"

workero test/cli/present/main.bc.wasm.js || fail "a rebuild without classes builds"
[ ! -e "$out/durable-object.js" ] || fail "a rebuild without classes removes durable-object.js"
grep -q "WorkeroDurableObject" "$out/index.js" && fail "a rebuild without classes drops the class exports"
echo "ok - a program without classes has no Durable Object glue"

probe_files() {
  for probe in workero-probe.mjs workero-probe.capnp workero-probe.log; do
    [ ! -e "$out/$probe" ] || fail "$1 leaves $probe in the output"
  done
}

rm -rf "$out"
if workero test/worker-init/main.bc.wasm.js; then fail "build fails when program initialisation raises"; fi
probe_files "a failing probe"
echo "ok - a failing probe leaves no probe files"

rm -rf "$out"
if WORKERO_PROBE_TIMEOUT=2 workero test/cli/hang/main.bc.wasm.js; then fail "build fails when initialisation never ends"; fi
grep -q "did not finish initialising in workerd within 2 seconds" "$log" || fail "the error reports the timeout"
probe_files "a timed out probe"
echo "ok - build fails when initialisation does not end in time"

rm -rf "$out"
WORKERD=workerd workero test/cli/present/main.bc.wasm.js || fail "WORKERD with a bare name is resolved through PATH"
echo "ok - WORKERD with a bare name is resolved through PATH"

rm -rf "$out"
if WORKERD=nonexistent-workerd workero test/cli/present/main.bc.wasm.js; then fail "a bare WORKERD that is not on PATH fails"; fi
grep -q "workero: WORKERD is set to nonexistent-workerd, which does not exist" "$log" || fail "the error names the missing bare workerd"
echo "ok - a bare WORKERD that is not on PATH fails"

rm -rf "$out"
if WORKERD=/nonexistent/workerd workero test/cli/present/main.bc.wasm.js; then fail "build fails without workerd"; fi
grep -q "workero: WORKERD is set to /nonexistent/workerd, which does not exist" "$log" || fail "the error names the missing workerd"
echo "ok - build fails when workerd is missing"

rm -rf "$out"
workero test/cli/entrypoints/main.bc.wasm.js || fail "a program with entrypoint classes builds"
grep -q "workero: entrypoint classes: Alpha, Beta, class" "$log" || fail "build lists the entrypoint classes"
[ -f "$out/entrypoint.js" ] || fail "entrypoint.js is written when an entrypoint is registered"
[ ! -e "$out/durable-object.js" ] || fail "a program without Durable Object classes has no durable-object.js"
for class in Alpha Beta class; do
  grep -q "^export { workero_class_[0-9]* as $class };" "$out/index.js" ||
    fail "index.js exports the entrypoint $class"
done
[ "$(grep -c 'for (const m of \["ping"\]) workero_class_[0-9]*.prototype' "$out/index.js")" -eq 3 ] ||
  fail "index.js adds the declared RPC methods to each entrypoint"
echo "ok - build exports the registered entrypoint classes"

workero test/cli/present/main.bc.wasm.js || fail "a rebuild without entrypoints builds"
[ ! -e "$out/entrypoint.js" ] || fail "a rebuild without entrypoints removes entrypoint.js"
echo "ok - a program without entrypoints has no entrypoint glue"

rm -rf "$out"
if workero test/cli/entrypoint-clash/main.bc.wasm.js; then fail "build fails when a Durable Object and an entrypoint share a name"; fi
grep -q 'class Same is registered twice' "$log" || fail "the error names the clashing class"
echo "ok - build fails when a Durable Object and an entrypoint share a name"

rm -rf "$out"
workero test/cli/workflows/main.bc.wasm.js || fail "a program with workflow classes builds"
grep -q "workero: workflow classes: Alpha, Beta, class" "$log" || fail "build lists the workflow classes"
[ -f "$out/workflow.js" ] || fail "workflow.js is written when a workflow is registered"
[ ! -e "$out/entrypoint.js" ] || fail "a program without entrypoints has no entrypoint.js"
for class in Alpha Beta class; do
  grep -q "^export { workero_class_[0-9]* as $class };" "$out/index.js" ||
    fail "index.js exports the workflow $class"
done
grep -q 'import { WorkeroWorkflow } from "./workflow.js";' "$out/index.js" || fail "index.js imports the workflow glue"
grep -q 'cloudflare:workflows' "$out/index.js" && fail "index.js does not import cloudflare:workflows itself"
echo "ok - build exports the registered workflow classes"

workero test/cli/present/main.bc.wasm.js || fail "a rebuild without workflows builds"
[ ! -e "$out/workflow.js" ] || fail "a rebuild without workflows removes workflow.js"
grep -q 'cloudflare:workflows' "$out/index.js" && fail "a worker without workflows does not import cloudflare:workflows"
echo "ok - a program without workflows has no workflow glue"

rm -rf "$out"
if workero test/cli/workflow-clash/main.bc.wasm.js; then fail "build fails when a Durable Object and a workflow share a name"; fi
grep -q 'class Same is registered twice' "$log" || fail "the error names the clashing workflow"
echo "ok - build fails when a Durable Object and a workflow share a name"
