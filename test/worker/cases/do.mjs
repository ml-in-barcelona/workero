import { report, runCases, sleep } from "./lib.mjs";

const to = (binding, name, op) => ["http://test/do/" + binding + "/" + name + "/" + op];
const counter = (name, op) => to("COUNTER", name, op);
const alarms = (name, op) => to("ALARMS", name, op);

const kvPut = (name, key, value) => ({
  name: `Storage.put ${key}`,
  request: counter(name, `kv-put?key=${key}&value=${encodeURIComponent(value)}`),
  status: 200,
  body: "200|put",
});

const cases = [
  { name: "Durable_object: one id keeps state across requests", request: counter("same", "incr"), status: 200, body: "200|1" },
  { name: "Durable_object: the second request sees the first", request: counter("same", "incr"), status: 200, body: "200|2" },
  { name: "Durable_object: another id has its own state", request: counter("other", "incr"), status: 200, body: "200|1" },
  { name: "Durable_object: the first id is unchanged by the other", request: counter("same", "get"), status: 200, body: "200|2" },
  { name: "Storage.get reads what the handler wrote", request: counter("same", "stored?key=count"), status: 200, body: "200|2" },
  { name: "Storage.get of an absent key", request: counter("same", "stored?key=nope"), status: 200, body: "200|none" },
  { name: "State.id gives the id of the object, with its name", request: counter("named", "id"), status: 200, check: (b) => (/^200\|named\|[0-9a-f]{64}$/.test(b) ? undefined : `unexpected ${b}`) },
  { name: "a class named like a reserved word is exported and works", request: to("CLASS", "r", "incr"), status: 200, body: "200|1" },
  { name: "Storage.get reads a Date written by JavaScript as its ISO string", request: counter("raw", "raw-put?kind=date"), status: 200, body: "200|put" },
  { name: "Storage.get of the Date", request: counter("raw", "stored?key=raw"), status: 200, body: '200|"1970-01-01T00:00:00.000Z"' },
  { name: "Storage.put a Map from JavaScript", request: counter("raw", "raw-put?kind=map"), status: 200, body: "200|put" },
  { name: "Storage.get reads a Map as {}", request: counter("raw", "stored?key=raw"), status: 200, body: "200|{}" },
  { name: "Storage.put a BigInt from JavaScript", request: counter("raw", "raw-put?kind=bigint"), status: 200, body: "200|put" },
  { name: "Storage.get raises Invalid_argument for a BigInt", request: counter("raw", "stored?key=raw"), status: 200, body: "200|Invalid_argument" },
  { name: "Storage.put a cyclic object from JavaScript", request: counter("raw", "raw-put?kind=cycle"), status: 200, body: "200|put" },
  { name: "Storage.get raises Invalid_argument for a cyclic object", request: counter("raw", "stored?key=raw"), status: 200, body: "200|Invalid_argument" },
  { name: "init runs once for a new object", request: counter("fresh", "creations"), status: 200, body: "200|1" },
  { name: "State.block_concurrency_while returns the value of an awaiting function", request: counter("bcw", "bcw"), status: 200, body: "200|after await" },
  kvPut("kv", "a:1", '{"x":[1,null]}'),
  kvPut("kv", "a:2", '"two"'),
  kvPut("kv", "b:1", "3"),
  kvPut("kv", "b:2", "true"),
  { name: "Storage.list returns every entry in key order", request: counter("kv", "kv-list"), status: 200, body: '200|a:1={"x":[1,null]},a:2="two",b:1=3,b:2=true,creations=1' },
  { name: "Storage.list with a prefix", request: counter("kv", "kv-list?prefix=b:"), status: 200, body: "200|b:1=3,b:2=true" },
  { name: "Storage.list with start and end", request: counter("kv", "kv-list?start=a:2&end=b:2"), status: 200, body: '200|a:2="two",b:1=3' },
  { name: "Storage.list reversed with a limit", request: counter("kv", "kv-list?reverse=true&limit=2"), status: 200, body: "200|creations=1,b:2=true" },
  { name: "Storage.delete of a present key", request: counter("kv", "kv-delete?key=b:1"), status: 200, body: "200|true" },
  { name: "Storage.delete of an absent key", request: counter("kv", "kv-delete?key=b:1"), status: 200, body: "200|false" },
  { name: "Storage.list sees the delete", request: counter("kv", "kv-list?prefix=b:"), status: 200, body: "200|b:2=true" },
  { name: "Storage.sync suspends and returns", request: counter("kv", "sync"), status: 200, body: "200|synced" },
  { name: "Storage.delete_all removes every key", request: counter("kv", "delete-all"), status: 200, body: "200|deleted" },
  { name: "Storage.list after delete_all", request: counter("kv", "kv-list"), status: 200, body: "200|" },
  { name: "State.wait_until: the object works", request: counter("bg", "wait-until"), status: 200, body: "200|scheduled" },
  {
    name: "Namespace.id_from_name, Id.to_string, Id.equal and id_from_string",
    request: ["http://test/do-ns/id?binding=COUNTER&name=idname"],
    status: 200,
    check: (b) => (/^len=64 name=idname same=true other=false restored=true$/.test(b) ? undefined : `unexpected ${b}`),
  },
  {
    name: "Namespace.unique_id gives distinct 64 digit ids",
    request: ["http://test/do-ns/unique?binding=COUNTER"],
    status: 200,
    body: "len=64 name=none distinct=true",
  },
  {
    name: "Namespace.unique_id passes the jurisdiction to the runtime, which workerd does not implement",
    request: ["http://test/do-ns/unique-eu?binding=COUNTER"],
    status: 200,
    bodyIncludes: "Jurisdiction restrictions are not implemented",
  },
  {
    name: "Namespace.get with a location hint reaches the same object as without",
    request: ["http://test/do-ns/unique-stub?binding=COUNTER"],
    status: 200,
    body: "1,2",
  },
  { name: "Namespace.id_from_string raises Js_error on a bad string", request: ["http://test/do-ns/bad-string?binding=COUNTER"], status: 200, body: "Js_error" },
  {
    name: "Namespace.of_env rejects a variable",
    request: ["http://test/do-ns/shape?binding=GREETING"],
    status: 200,
    body: 'Workero.Durable_object.Namespace.of_env: binding "GREETING" is a string, not a Durable Object namespace',
  },
  {
    name: "Namespace.of_env rejects a missing binding",
    request: ["http://test/do-ns/shape?binding=NOPE"],
    status: 200,
    body: 'Workero.Durable_object.Namespace.of_env: binding "NOPE" not found',
  },
  {
    name: "A stub fetch on an object without a fetch handler fails",
    request: to("NOFETCH", "n", "x"),
    status: 502,
    bodyIncludes: "fetch()",
  },
  {
    name: "Promise.await in the create function fails the object with a clear error",
    request: to("AWAITING", "a", "x"),
    status: 502,
    bodyIncludes: "Promise.await is not allowed here",
  },
];

const pollFor = async (env, path, expected, name, failures) => {
  const problems = [];
  const deadline = Date.now() + 15000;
  let last = "";
  while (Date.now() < deadline) {
    last = await (await env.WORKER.fetch("http://test/do/ALARMS/" + path)).text();
    if (last === expected) break;
    await sleep(100);
  }
  if (last !== expected) problems.push(`last ${last}, expected ${expected}`);
  report(name, problems, failures);
};

const text = async (env, url) => await (await env.WORKER.fetch(url)).text();

const checkText = async (env, name, url, expected, failures) => {
  const actual = await text(env, url);
  report(name, actual === expected ? [] : [`got ${actual}, expected ${expected}`], failures);
};

export default async (env, failures) => {
  await runCases(env, cases, failures);

  await checkText(env, "State.wait_until keeps the work going after the response", "http://test/do/COUNTER/bg/stored?key=background", "200|none", failures);
  await sleep(500);
  await checkText(env, "State.wait_until work completes", "http://test/do/COUNTER/bg/stored?key=background", '200|"done"', failures);

  await checkText(env, "an object counts before it is reset", "http://test/do/COUNTER/reset/incr", "200|1", failures);
  await runCases(
    env,
    [{ name: "block_concurrency_while that raises fails the running request with that exception", request: counter("reset", "bcw-raises"), status: 502, bodyIncludes: "reset me" }],
    failures,
  );
  await sleep(200);
  await checkText(env, "init reloads the stored count after the object is recreated", "http://test/do/COUNTER/reset/get", "200|1", failures);
  await checkText(env, "the object ran init again after the reset", "http://test/do/COUNTER/reset/creations", "200|2", failures);

  await checkText(env, "get_alarm is None without an alarm", "http://test/do/ALARMS/none/get", "200|none", failures);
  const at = Date.now() + 60000;
  await checkText(env, "set_alarm schedules the alarm", `http://test/do/ALARMS/far/set-at?at=${at}`, "200|set", failures);
  await checkText(env, "get_alarm returns the time given to set_alarm", "http://test/do/ALARMS/far/get", `200|${at}`, failures);
  await checkText(env, "delete_alarm cancels the alarm", "http://test/do/ALARMS/far/delete", "200|deleted", failures);
  await checkText(env, "get_alarm is None after delete_alarm", "http://test/do/ALARMS/far/get", "200|none", failures);

  await checkText(env, "set_alarm_after accepts its options", "http://test/do/ALARMS/soon/set?ms=50&allow_concurrency=true&allow_unconfirmed=true", "200|set", failures);
  await pollFor(env, "soon/status", "200|fired=1 attempts=1 last=0:false", "the alarm handler runs once, with retry_count 0", failures);
  await checkText(env, "the alarm is cleared once it has run", "http://test/do/ALARMS/soon/get", "200|none", failures);

  await checkText(env, "the alarm handler can be made to fail once", "http://test/do/ALARMS/retry/mode?value=fail-once", "200|mode set", failures);
  await checkText(env, "set_alarm_after schedules the failing alarm", "http://test/do/ALARMS/retry/set?ms=50", "200|set", failures);
  await pollFor(env, "retry/status", "200|fired=1 attempts=2 last=1:true", "an exception in the alarm handler makes the runtime retry it", failures);

  await checkText(env, "a deleted alarm never runs", "http://test/do/ALARMS/gone/set?ms=300", "200|set", failures);
  await checkText(env, "delete the pending alarm", "http://test/do/ALARMS/gone/delete", "200|deleted", failures);
  await sleep(1000);
  await checkText(env, "the deleted alarm did not run", "http://test/do/ALARMS/gone/status", "200|fired=0 attempts=0 last=none", failures);
};
