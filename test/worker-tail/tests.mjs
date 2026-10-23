const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const readSink = async (env) => (await env.SINK.fetch("http://sink/")).json();

const waitUntil = async (env, ready) => {
  let seen;
  for (let i = 0; i < 100; i++) {
    seen = { ...(await readSink(env)), meta: await (await env.SINK_2.fetch("http://sink/")).json() };
    if (ready(seen)) return seen;
    await sleep(50);
  }
  throw new Error(`trace items did not arrive, the sinks have ${JSON.stringify(seen)}`);
};

const fetchItem = (items, pathname) => items.find((i) => i.event.kind === "fetch" && new URL(i.event.url).pathname === pathname);
const byKind = (items, kind) => items.find((i) => i.event.kind === kind);

const check = (name, actual, expected) => {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  return a === e ? [] : [`${name} is ${a}, expected ${e}`];
};

const cases = [
  {
    name: "a fetch item has the event, status, outcome, logs and redacted headers",
    run: ({ items }) => {
      const item = fetchItem(items, "/log");
      if (!item) return ["no item for /log"];
      return [
        ...check("outcome", item.outcome, "ok"),
        ...check("method", item.event.method, "GET"),
        ...check("status", item.event.status, 200),
        ...check("redacted header", item.event.headers.authorization, "REDACTED"),
        ...check("unredacted header", item.event.unredacted_headers.authorization, "Bearer x"),
        ...check("script_name", item.script_name, null),
        ...check("event_timestamp_set", item.event_timestamp_set, true),
        ...check("truncated", item.truncated, false),
        ...check(
          "logs",
          item.logs.map((l) => [l.level, l.timestamp_set, l.message]),
          [
            ["log", true, ["hello", 1, { a: 2 }]],
            ["warn", true, ["careful"]],
          ],
        ),
        ...check("exceptions", item.exceptions, []),
      ];
    },
  },
  {
    name: "a fetch item reads the cf copy without raising",
    run: ({ items }) => {
      const item = fetchItem(items, "/log");
      return item ? check("country", item.event.country, null) : ["no item for /log"];
    },
  },
  {
    name: "a handler that raises gives an Exception item with no status",
    run: ({ items }) => {
      const item = fetchItem(items, "/throw");
      if (!item) return ["no item for /throw"];
      return [
        ...check("outcome", item.outcome, "exception"),
        ...check("status", item.event.status, null),
        ...check("exceptions", item.exceptions, [{ name: "Error", message: "boom", has_stack: true }]),
      ];
    },
  },
  {
    name: "a scheduled invocation gives a Scheduled event",
    run: ({ items }) => {
      const item = byKind(items, "scheduled");
      if (!item) return ["no scheduled item"];
      return [
        ...check("outcome", item.outcome, "ok"),
        ...check("cron", item.event.cron, "*/5 * * * *"),
        ...check("scheduled_time", item.event.scheduled_time, 1700000000000),
      ];
    },
  },
  {
    name: "a queue invocation gives a Queue event",
    run: ({ items }) => {
      const item = byKind(items, "queue");
      if (!item) return ["no queue item"];
      return [
        ...check("outcome", item.outcome, "ok"),
        ...check("queue", item.event.queue, "jobs"),
        ...check("batch_size", item.event.batch_size, 2),
      ];
    },
  },
  {
    name: "log arguments with no JSON form read as JSON the runtime serialized",
    run: ({ items }) => {
      const item = fetchItem(items, "/odd");
      if (!item) return ["no item for /odd"];
      return check("message", item.logs[0]?.message, [null, "10", {}, "() => 1"]);
    },
  },
  {
    name: "the handler awaits a fetch and wait_until runs after it",
    run: ({ items, after }) => [
      ...check("after has one entry per item", after.length, items.length),
      ...check("every call got whole batches of one", after.filter((n) => n !== 1), []),
    ],
  },
  {
    name: "an RPC call gives an Rpc event",
    run: ({ items }) => {
      const item = byKind(items, "rpc");
      return item ? check("method", item.event.method, "ping") : ["no rpc item"];
    },
  },
  {
    name: "a Durable Object alarm gives an Alarm event",
    run: ({ items }) => {
      const item = byKind(items, "alarm");
      return item ? check("scheduled_time_set", item.event.scheduled_time_set, true) : ["no alarm item"];
    },
  },
  {
    name: "hibernated WebSocket events give Hibernatable_websocket events",
    run: ({ items }) =>
      check(
        "events",
        items.filter((i) => i.event.kind === "hibernatable_websocket").map((i) => i.event.event).sort(),
        ["close:1000:true", "message"],
      ),
  },
  {
    name: "the invocation of a tail Worker gives a Tail event",
    run: ({ meta }) => {
      const consumed = meta.items.filter((i) => i.event.kind === "tail").map((i) => JSON.stringify(i.event.consumed));
      return consumed.includes("[null]") ? [] : [`no tail item that consumed the producer, got ${consumed}`];
    },
  },
  {
    name: "a streaming tail gets the onset, the logs, the return and the outcome in order",
    run: ({ stream }) => {
      const events = invocation(stream, "/log");
      if (!events) return ["no stream onset for /log"];
      const onset = events[0].event;
      return [
        ...check("sequences", events.map((e) => e.sequence), events.map((_, i) => i)),
        ...check("onset", [onset.kind, onset.info.kind, onset.info.method, onset.execution_model, onset.span_id_set], ["onset", "fetch", "GET", "stateless", true]),
        ...check("trace id", events.every((e) => e.trace_id_set && e.timestamp_set), true),
        ...check(
          "kinds",
          events.slice(1).map((e) => e.event.kind),
          ["log", "log", "return", "outcome"],
        ),
        ...check("log", events.slice(1, 3).map((e) => [e.event.level, e.event.message]), [["log", ["hello", 1, { a: 2 }]], ["warn", ["careful"]]]),
        ...check("return", events[3].event.status, 200),
        ...check("outcome", events[4].event.outcome, "ok"),
      ];
    },
  },
  {
    name: "a streaming tail gets the exception of a handler that raises",
    run: ({ stream }) => {
      const events = invocation(stream, "/throw");
      if (!events) return ["no stream onset for /throw"];
      const exception = events.find((e) => e.event.kind === "exception");
      return [
        ...check("exception", exception && [exception.event.name, exception.event.message, exception.event.has_stack], ["Error", "boom", true]),
        ...check("outcome", events.at(-1).event.outcome, "exception"),
      ];
    },
  },
  {
    name: "a streaming tail gets the info of a scheduled, a queue and an RPC invocation",
    run: ({ stream }) =>
      check(
        "infos",
        ["scheduled", "queue", "jsrpc", "alarm"].map((kind) => stream.some((e) => e.event.kind === "onset" && e.event.info.kind === kind)),
        [true, true, true, true],
      ),
  },
];

const invocation = (stream, pathname) => {
  const onset = stream.find((e) => e.event.kind === "onset" && e.event.info.url && new URL(e.event.info.url).pathname === pathname);
  return onset && stream.filter((e) => e.invocation_id === onset.invocation_id).sort((a, b) => a.sequence - b.sequence);
};

export default {
  async test(_controller, env) {
    await env.SINK.fetch("http://sink/", { method: "DELETE" });
    await env.SINK_2.fetch("http://sink/", { method: "DELETE" });
    await (await env.PRODUCER.fetch("http://test/log?token=abc", { headers: { authorization: "Bearer x" } })).text();
    await (await env.PRODUCER.fetch("http://test/odd")).text();
    await env.PRODUCER.fetch("http://test/throw").then(
      (response) => response.text(),
      () => undefined,
    );
    await env.PRODUCER.scheduled({ cron: "*/5 * * * *", scheduledTime: 1700000000000 });
    await env.PRODUCER.queue("jobs", [
      { id: "m1", timestamp: new Date(0), body: "a", attempts: 1 },
      { id: "m2", timestamp: new Date(0), body: "b", attempts: 1 },
    ]);
    await env.RPC.ping();
    await (await env.PRODUCER.fetch("http://test/alarm")).text();
    const upgrade = await env.PRODUCER.fetch("http://test/ws", { headers: { Upgrade: "websocket" } });
    const ws = upgrade.webSocket;
    ws.accept();
    const echoed = new Promise((resolve) => ws.addEventListener("message", resolve));
    ws.send("hi");
    await echoed;
    ws.close(1000);
    const kinds = ["fetch", "scheduled", "queue", "rpc", "alarm", "hibernatable_websocket"];
    const seen = await waitUntil(
      env,
      (s) =>
        kinds.every((k) => s.items.some((i) => i.event.kind === k)) &&
        s.items.filter((i) => i.event.kind === "hibernatable_websocket").length >= 2 &&
        s.after.length >= s.items.length &&
        s.meta.items.some((i) => i.event.kind === "tail") &&
        s.stream.some((e) => e.event.kind === "outcome"),
    );
    await sleep(300);
    const final = await waitUntil(env, () => true);
    const failures = [];
    for (const c of cases) {
      const problems = c.run(final);
      if (problems.length) failures.push(`${c.name}: ${problems.join("; ")}`);
      console.log(`${problems.length ? "FAIL" : "ok"} - ${c.name}`);
    }
    if (failures.length) throw new Error(failures.join("\n") + "\n" + JSON.stringify(final));
  },
};
