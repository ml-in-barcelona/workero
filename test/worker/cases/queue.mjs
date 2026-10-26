import { runCases, report } from "./lib.mjs";

const readLog = async (env) => (await env.SINK.fetch("http://sink/log")).json();
const clearLog = async (env) => (await env.SINK.fetch("http://sink/log", { method: "DELETE" })).text();

const msg = (id, body, attempts = 1) => ({ id, timestamp: new Date(1700000000000), body, attempts });
const bytes = (...values) => new Uint8Array(values).buffer;

const delayText = (n) =>
  [
    `invalid: Workero.Queue.send: delay_seconds ${n} is outside 0 to 86400`,
    `invalid: Workero.Queue.message: delay_seconds ${n} is outside 0 to 86400`,
    `invalid: Workero.Queue.send_batch: delay_seconds ${n} is outside 0 to 86400`,
  ].join("\n");

const shape = (name, found) => `Workero.Queue.of_env: binding "${name}" ${found}`;

const producerCases = [
  {
    name: "Queue.send sends a Json body with content type json",
    request: ["http://test/queue/send?kind=json"],
    log: [{ path: "/message", format: "json", delay: null, body: '{"id":7,"tags":["a","b"]}' }],
  },
  {
    name: "Queue.send sends a Text body with content type text and the delay",
    request: ["http://test/queue/send?kind=text&delay=30"],
    log: [{ path: "/message", format: "text", delay: "30", body: "héllo" }],
  },
  {
    name: "Queue.send sends a Bytes body as raw bytes with content type bytes",
    request: ["http://test/queue/send?kind=bytes"],
    log: [{ path: "/message", format: "bytes", delay: null, body: "00ff800a" }],
  },
  {
    name: "Queue.send accepts the delay limits",
    request: ["http://test/queue/send?kind=text&delay=86400"],
    log: [{ path: "/message", format: "text", delay: "86400", body: "héllo" }],
  },
  {
    name: "Queue.send with content type v8 sends a Json body as a v8 message",
    request: ["http://test/queue/send?kind=json&ct=v8"],
    log: [{ path: "/message", format: "v8", delay: null, body: "ff0f6f22026964490e22047461677341022201612201622400027b02" }],
  },
  {
    name: "Queue.send with content type v8 sends a Text body as a v8 message with the delay",
    request: ["http://test/queue/send?kind=text&ct=v8&delay=4"],
    log: [{ path: "/message", format: "v8", delay: "4", body: "ff0f220568e96c6c6f" }],
  },
  {
    name: "Queue.send with content type v8 sends a Bytes body as a v8 message",
    request: ["http://test/queue/send?kind=bytes&ct=v8"],
    log: [{ path: "/message", format: "v8", delay: null, body: "ff0f420400ff800a5642000400" }],
  },
  {
    name: "Queue.send accepts the content type that the body implies",
    request: ["http://test/queue/send?kind=json&ct=json"],
    log: [{ path: "/message", format: "json", delay: null, body: '{"id":7,"tags":["a","b"]}' }],
  },
  {
    name: "Queue.send_batch sends v8 messages next to default ones",
    request: ["http://test/queue/send-batch-v8"],
    log: [
      {
        path: "/batch",
        delay: null,
        messages: [
          { format: "v8", delay: null, body: "ff0f6f22026964490e22047461677341022201612201622400027b02" },
          { format: "v8", delay: "3", body: "ff0f2205706c61696e" },
          { format: "text", delay: null, body: "default" },
        ],
      },
    ],
  },
  {
    name: "Queue.send_batch sends each body with its content type and delay, and the batch delay",
    request: ["http://test/queue/send-batch?delay=2"],
    log: [
      {
        path: "/batch",
        delay: "2",
        messages: [
          { format: "json", delay: "9", body: '{"id":7,"tags":["a","b"]}' },
          { format: "text", delay: null, body: "plain" },
          { format: "bytes", delay: null, body: "00ff" },
        ],
      },
    ],
  },
  {
    name: "Queue.send_batch without a delay sends none",
    request: ["http://test/queue/send-batch"],
    log: [
      {
        path: "/batch",
        delay: null,
        messages: [
          { format: "json", delay: "9", body: '{"id":7,"tags":["a","b"]}' },
          { format: "text", delay: null, body: "plain" },
          { format: "bytes", delay: null, body: "00ff" },
        ],
      },
    ],
  },
];

const runProducer = async (env, failures) => {
  for (const c of producerCases) {
    const problems = [];
    await clearLog(env);
    const response = await env.WORKER.fetch(...c.request);
    const body = await response.text();
    if (response.status !== 200 || body !== "sent") problems.push(`status ${response.status} body ${JSON.stringify(body)}`);
    const log = await readLog(env);
    if (JSON.stringify(log) !== JSON.stringify(c.log))
      problems.push(`log ${JSON.stringify(log)}, expected ${JSON.stringify(c.log)}`);
    report(c.name, problems, failures);
  }
};

const httpCases = [
  {
    name: "Queue.send raises Js_error when the queue rejects the message",
    request: ["http://test/queue/send-rejected"],
    status: 502,
    bodyIncludes: "Error: ",
  },
  { name: "Queue.send, message and send_batch reject a negative delay", request: ["http://test/queue/bad-delay?delay=-1"], status: 200, body: delayText(-1) },
  { name: "Queue.send, message and send_batch reject a delay over 86400", request: ["http://test/queue/bad-delay?delay=86401"], status: 200, body: delayText(86401) },
  {
    name: "Queue.send and message reject a content type other than v8 that the body does not imply",
    request: ["http://test/queue/bad-content-type"],
    status: 200,
    body: [
      "invalid: Workero.Queue.send: content type text does not match a json body",
      "invalid: Workero.Queue.message: content type bytes does not match a text body",
    ].join("\n"),
  },
  { name: "Queue.of_env rejects a variable", request: ["http://test/queue/shape?name=GREETING"], status: 200, body: shape("GREETING", "is a string, not a queue producer") },
  {
    name: "Queue.of_env rejects an object without send",
    request: ["http://test/queue/shape?name=SETTINGS"],
    status: 200,
    body: shape("SETTINGS", "is an object without method send, not a queue producer"),
  },
  { name: "Queue.of_env of a missing binding", request: ["http://test/queue/shape?name=NOPE"], status: 200, body: shape("NOPE", "not found") },
  { name: "Queue.of_env accepts the producer binding", request: ["http://test/queue/shape?name=JOBS"], status: 200, body: "ok" },
];

const consumerCases = [
  {
    name: "the consumer reads id, timestamp, attempts and a JSON body",
    queue: "read-json",
    messages: [msg("m1", { a: [1, 2] }), msg("m2", "str", 3)],
    log: [
      'id=m1;ts=1700000000000;attempts=1;json={"a":[1,2]}',
      'id=m2;ts=1700000000000;attempts=3;json="str"',
    ],
  },
  {
    name: "the consumer reads a text body",
    queue: "read-text",
    messages: [msg("m1", "héllo")],
    log: ["id=m1;ts=1700000000000;attempts=1;text=héllo"],
  },
  {
    name: "the consumer reads a bytes body",
    queue: "read-bytes",
    messages: [msg("m1", bytes(0, 255, 1))],
    log: ["id=m1;ts=1700000000000;attempts=1;bytes=00ff01"],
  },
  {
    name: "body_text raises Invalid_argument for a body that is not a string",
    queue: "read-wrong-type",
    messages: [msg("m1", { a: 1 })],
    log: ["invalid: Workero.Decode: expected string, got object"],
  },
  {
    name: "the consumer sees every message of the batch",
    queue: "count",
    messages: [msg("m1", "a"), msg("m2", "b"), msg("m3", "c")],
    log: ["3"],
  },
  {
    name: "Message.ack and Message.retry act on their own message",
    queue: "by-body",
    messages: [msg("m1", "ack"), msg("m2", "retry"), msg("m3", "retry5"), msg("m4", "none")],
    result: {
      outcome: "ok",
      ackAll: false,
      retryBatch: { retry: false },
      explicitAcks: ["m1"],
      retryMessages: [{ msgId: "m2" }, { msgId: "m3", delaySeconds: 5 }],
    },
  },
  {
    name: "Batch.ack_all acks the batch",
    queue: "ack-all",
    messages: [msg("m1", "a")],
    result: { outcome: "ok", ackAll: true, retryBatch: { retry: false }, explicitAcks: [], retryMessages: [] },
  },
  {
    name: "Batch.retry_all retries the batch",
    queue: "retry-all",
    messages: [msg("m1", "a")],
    result: { outcome: "ok", ackAll: false, retryBatch: { retry: true }, explicitAcks: [], retryMessages: [] },
  },
  {
    name: "Batch.retry_all with a delay retries the batch after the delay",
    queue: "retry-all-delay",
    messages: [msg("m1", "a")],
    result: { outcome: "ok", ackAll: false, retryBatch: { retry: true, delaySeconds: 7 }, explicitAcks: [], retryMessages: [] },
  },
  {
    name: "retry_all and retry reject a delay outside 0 to 86400",
    queue: "bad-delay",
    messages: [msg("m1", "a")],
    log: [
      "invalid: Workero.Queue.Batch.retry_all: delay_seconds 86401 is outside 0 to 86400",
      "invalid: Workero.Queue.Message.retry: delay_seconds -1 is outside 0 to 86400",
    ],
  },
  {
    name: "a consumer that raises rejects the event and keeps the explicit ack",
    queue: "raise-after-ack",
    messages: [msg("m1", "a"), msg("m2", "b")],
    result: { outcome: "exception", ackAll: false, retryBatch: { retry: false }, explicitAcks: ["m1"], retryMessages: [] },
  },
];

const runConsumer = async (env, failures) => {
  for (const c of consumerCases) {
    const problems = [];
    await clearLog(env);
    const result = await env.WORKER.queue(c.queue, c.messages);
    const expected = c.result ?? { outcome: "ok", ackAll: false, retryBatch: { retry: false }, explicitAcks: [], retryMessages: [] };
    if (JSON.stringify(result) !== JSON.stringify(expected))
      problems.push(`result ${JSON.stringify(result)}, expected ${JSON.stringify(expected)}`);
    const log = (await readLog(env)).map((entry) => entry.body);
    const expectedLog = c.log ?? [];
    if (JSON.stringify(log) !== JSON.stringify(expectedLog))
      problems.push(`log ${JSON.stringify(log)}, expected ${JSON.stringify(expectedLog)}`);
    report(c.name, problems, failures);
  }
};

export default async (env, failures) => {
  await runProducer(env, failures);
  await runCases(env, httpCases, failures);
  await runConsumer(env, failures);
};
