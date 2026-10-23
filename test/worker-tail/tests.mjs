const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const readSink = async (env) => (await env.SINK.fetch("http://sink/")).json();

const waitFor = async (env, count) => {
  let seen;
  for (let i = 0; i < 100; i++) {
    seen = await readSink(env);
    if (seen.items.length >= count && seen.after.length >= count) return seen;
    await sleep(50);
  }
  throw new Error(`expected ${count} trace items, the sink has ${JSON.stringify(seen)}`);
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
      ...check("items", items.length, 5),
      ...check("after", after, [1, 1, 1, 1, 1]),
    ],
  },
];

const classCase = async (env) => {
  await env.SINK_CLASS.fetch("http://sink/", { method: "DELETE" });
  await (await env.PRODUCER_CLASS.fetch("http://test/log?token=abc")).text();
  let seen;
  for (let i = 0; i < 100; i++) {
    seen = await (await env.SINK_CLASS.fetch("http://sink/")).json();
    if (seen.items.length >= 1 && seen.after.length >= 1) break;
    await sleep(50);
  }
  const item = seen.items.find((i) => i.event.kind === "fetch" && new URL(i.event.url).pathname === "/log");
  const problems = item
    ? [...check("outcome", item.outcome, "ok"), ...check("status", item.event.status, 200), ...check("logs", item.logs.map((l) => l.message), [["hello", 1, { a: 2 }], ["careful"]]), ...check("after", seen.after, [1])]
    : [`no item for /log in ${JSON.stringify(seen)}`];
  console.log(`${problems.length ? "FAIL" : "ok"} - an entrypoint class receives the tail events of its producer`);
  return problems.length ? [`class tail: ${problems.join("; ")}`] : [];
};

export default {
  async test(_controller, env) {
    await env.SINK.fetch("http://sink/", { method: "DELETE" });
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
    const seen = await waitFor(env, 5);
    const failures = await classCase(env);
    for (const c of cases) {
      const problems = c.run(seen);
      if (problems.length) failures.push(`${c.name}: ${problems.join("; ")}`);
      console.log(`${problems.length ? "FAIL" : "ok"} - ${c.name}`);
    }
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
