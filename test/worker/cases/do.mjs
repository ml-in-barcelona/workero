import { report, runCases, sleep } from "./lib.mjs";

const to = (binding, name, op) => ["http://test/do/" + binding + "/" + name + "/" + op];
const counter = (name, op) => to("COUNTER", name, op);
const alarms = (name, op) => to("ALARMS", name, op);

const sqlite = (op) => to("SQLITE", "db", op);

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
  { name: "State.container is None when the class has no container", request: counter("nocontainer", "container"), status: 200, body: "200|none" },
  {
    name: "Container calls the container API with the options, the signal, the port, TCP connect, the inactivity timeout and the interceptors (stub)",
    request: ["http://test/do-container-stub"],
    status: 200,
    body: 'start:{"entrypoint":["sh","-c","x"],"env":{"A":"1"},"enableInternet":true};start:{};monitor;signal:15;destroy:bye;destroy:-;connect:9000:10.0.0.1:9000;timeout:60000;http:*.example.com:a;all:b;https:*:c|Error: exit 3|port 8080 http://container/x|ping|invalid,invalid,invalid',
  },
  { name: "a class named like a reserved word is exported and works", request: to("CLASS", "r", "incr"), status: 200, body: "200|1" },
  { name: "Storage.get reads a Date written by JavaScript as its ISO string", request: counter("raw", "raw-put?kind=date"), status: 200, body: "200|put" },
  { name: "Storage.get of the Date", request: counter("raw", "stored?key=raw"), status: 200, body: '200|"1970-01-01T00:00:00.000Z"' },
  { name: "Storage.put a Map from JavaScript", request: counter("raw", "raw-put?kind=map"), status: 200, body: "200|put" },
  { name: "Storage.get reads a Map as {}", request: counter("raw", "stored?key=raw"), status: 200, body: "200|{}" },
  { name: "Storage.put a BigInt from JavaScript", request: counter("raw", "raw-put?kind=bigint"), status: 200, body: "200|put" },
  { name: "Storage.get raises Invalid_argument for a BigInt", request: counter("raw", "stored?key=raw"), status: 200, body: "200|Invalid_argument" },
  { name: "Storage.put a cyclic object from JavaScript", request: counter("raw", "raw-put?kind=cycle"), status: 200, body: "200|put" },
  { name: "Storage.get raises Invalid_argument for a cyclic object", request: counter("raw", "stored?key=raw"), status: 200, body: "200|Invalid_argument" },
  { name: "Sql.run creates a table and inserts a row with every parameter type", request: sqlite("setup"), status: 200, body: "200|1" },
  {
    name: "Sql.query returns typed rows with their column names",
    request: sqlite("rows"),
    status: 200,
    body: "200|id=i1,name=ta,score=f1.5,data=b00ff;id=i2,name=null,score=f2.25,data=null",
  },
  { name: "Sql.run returns the rows written", request: sqlite("update"), status: 200, body: "200|2" },
  { name: "Sql.query sees the update", request: sqlite("rows"), status: 200, check: (b) => (b.includes("name=tz") && !b.includes("name=ta") ? undefined : `unexpected ${b}`) },
  { name: "Sql round-trips 2^53-1 and rejects an Int beyond 2^53", request: sqlite("big"), status: 200, body: "200|id=i9007199254740991|Invalid_argument" },
  { name: "Sql.query raises Js_error on a syntax error", request: sqlite("syntax"), status: 200, bodyIncludes: "syntax error" },
  { name: "Sql.database_size is positive", request: sqlite("size"), status: 200, body: "200|true" },
  { name: "transaction_sync commits and returns the result of its function", request: sqlite("tx-commit"), status: 200, body: "200|42 count=4 k=1" },
  { name: "transaction_sync rolls back SQL and storage and re-raises the original exception", request: sqlite("tx-rollback"), status: 200, body: "200|Failure boom count=4 k2=none" },
  {
    name: "Promise.await in transaction_sync raises Invalid_argument and rolls back",
    request: sqlite("tx-await"),
    status: 200,
    body: "200|Workero.Durable_object.Storage.transaction_sync: Promise.await is not allowed here count=4",
  },
  { name: "an SQL error in transaction_sync raises Js_error and rolls back", request: sqlite("tx-sql-error"), status: 200, body: "200|Js_error count=4" },
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
  { name: "Sql.query reads a whole REAL as Int and an INTEGER beyond 2^53 as a Float", request: sqlite("numbers"), status: 200, body: "200|real_whole=i2,big=f1.15292e+18,frac=f1.5" },
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

const bounded = (promise, ms, message) => {
  let timer;
  const timeout = new Promise((_, reject) => (timer = setTimeout(() => reject(new Error(message)), ms)));
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
};

const text = (env, url) => bounded(env.WORKER.fetch(url).then((res) => res.text()), 5000, `request timed out: ${url}`);

const checkText = async (env, name, url, expected, failures) => {
  const actual = await text(env, url);
  report(name, actual === expected ? [] : [`got ${actual}, expected ${expected}`], failures);
};

let opened = [];

const connect = async (env, path) => {
  const res = await bounded(env.WORKER.fetch(`http://test${path}`, { headers: { Upgrade: "websocket" } }), 5000, "upgrade timed out");
  const ws = res.webSocket;
  if (!ws) throw new Error(`no webSocket, status ${res.status}`);
  ws.accept();
  opened.push(ws);
  ws.binaryType = "arraybuffer";
  const events = [];
  let wake = () => {};
  const push = (e) => {
    events.push(e);
    wake();
  };
  ws.addEventListener("message", (e) => push(typeof e.data === "string" ? e.data : new Uint8Array(e.data)));
  ws.addEventListener("close", (e) => push({ close: e.code }));
  const next = async () => {
    const deadline = Date.now() + 3000;
    while (events.length === 0) {
      if (Date.now() > deadline) throw new Error("timed out waiting for an event");
      await Promise.race([new Promise((r) => (wake = r)), sleep(50)]);
    }
    return events.shift();
  };
  return { ws, next };
};

const hibernation = async (env, failures) => {
  const check = async (name, body) => {
    const problems = [];
    try {
      await body((label, actual, expected) => {
        if (JSON.stringify(actual) !== JSON.stringify(expected)) problems.push(`${label}: ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
      });
    } catch (error) {
      problems.push(`threw ${error}`);
    } finally {
      for (const ws of opened) {
        try {
          ws.close(1000);
        } catch {}
      }
      opened = [];
    }
    report(name, problems, failures);
  };
  const path = (name, tags) => `/do-ws/ROOMS/${name}/connect${tags ? `?tags=${tags}` : ""}`;

  await check("hibernatable WebSocket: messages reach websocket_message and replies come back", async (expect) => {
    const { ws, next } = await connect(env, path("echo"));
    ws.send("a");
    expect("first reply", await next(), "1:a");
    ws.send("b");
    expect("second reply", await next(), "2:b");
    ws.send(new Uint8Array([1, 2]));
    expect("binary reply", new TextDecoder().decode(await next()), "0102");
    ws.send("ping");
    expect("auto response", await next(), "pong");
    ws.close(1000, "done");
  });
  await checkText(env, "the auto response did not wake the handler", "http://test/do/ROOMS/echo/handled", "200|3", failures);

  await check("State.tags, State.websockets and broadcast", async (expect) => {
    const one = await connect(env, path("group", "room,a"));
    const two = await connect(env, path("group", "room"));
    one.ws.send("tags");
    expect("tags", await one.next(), "room,a");
    two.ws.send("peers");
    expect("peers", await two.next(), "2");
    one.ws.send("broadcast");
    expect("broadcast to one", await one.next(), "hello all");
    expect("broadcast to two", await two.next(), "hello all");
    one.ws.close(1000);
    two.ws.close(1000);
  });

  await check("a hibernatable socket on a class without websocket_message gets no reply and stays usable", async (expect) => {
    const { ws, next } = await connect(env, `/do-ws/NOWSHANDLER/nohandler/connect`);
    ws.send("x");
    let got;
    try {
      got = await next();
    } catch (e) {
      got = String(e);
    }
    expect("outcome", got, "Error: timed out waiting for an event");
    ws.close(1000);
  });

  await check("websocket_close receives the code, reason and was_clean", async (expect) => {
    const { ws } = await connect(env, path("closing"));
    ws.send("x");
    ws.close(4000, "bye");
    let last = "";
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      last = await text(env, "http://test/do/ROOMS/closing/closed");
      if (last !== "200|none") break;
      await sleep(100);
    }
    expect("closed", last, "200|4000:bye:true");
  });
};

export default async (env, failures) => {
  await runCases(env, cases, failures);

  await checkText(env, "State.wait_until: the object answers before the work is done", "http://test/do/COUNTER/bg/wait-until", "200|scheduled", failures);
  await checkText(env, "State.wait_until keeps the work going after the response", "http://test/do/COUNTER/bg/stored?key=background", "200|none", failures);
  {
    const problems = [];
    let last = "";
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      last = await text(env, "http://test/do/COUNTER/bg/stored?key=background");
      if (last === '200|"done"') break;
      await sleep(100);
    }
    if (last !== '200|"done"') problems.push(`last ${last}`);
    report("State.wait_until work completes", problems, failures);
  }

  await hibernation(env, failures);

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
