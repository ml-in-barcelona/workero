import { report, runCases, sleep } from "./lib.mjs";

const sum = (bytes) => bytes.reduce((a, b) => (a + b) % 65521, 0);

const slowBody = (chunks, size, ms) => {
  let n = 0;
  return new ReadableStream({
    async pull(controller) {
      if (n === chunks) return controller.close();
      controller.enqueue(new Uint8Array(size).fill(++n));
      await sleep(ms);
    },
  });
};

const bodyCases = async (env, failures) => {
  const post = async (body) => {
    const res = await env.WORKER.fetch("http://test/stream/body", {
      method: "POST",
      body,
      duplex: "half",
    });
    return res.text();
  };
  const slow = await post(slowBody(4, 10, 20));
  const slowSum = sum([1, 2, 3, 4].flatMap((n) => new Array(10).fill(n)));
  report(
    "stream: request body arrives chunk by chunk",
    slow === `chunks=4 total=40 sum=${slowSum}` ? [] : [slow],
    failures,
  );
  const big = new Uint8Array(1 << 20).map((_, i) => (i * 7) % 256);
  const bigText = await post(big);
  const [, chunks, total, bigSum] = bigText.match(/chunks=(\d+) total=(\d+) sum=(\d+)/) ?? [];
  const problems = [];
  if (Number(total) !== big.length) problems.push(`total ${total}`);
  if (Number(bigSum) !== sum(big)) problems.push(`sum ${bigSum}, expected ${sum(big)}`);
  if (!(Number(chunks) > 1)) problems.push(`chunks ${chunks}`);
  report("stream: 1 MiB request body", problems, failures);
};

const state = async (env) => {
  const text = await (await env.WORKER.fetch("http://test/stream/state")).text();
  return Object.fromEntries(text.split(" ").map((kv) => kv.split("=")));
};

const decoder = new TextDecoder();

const responseStreamCases = async (env, failures) => {
  const t0 = Date.now();
  const res = await env.WORKER.fetch("http://test/stream/chunks");
  const reader = res.body.getReader();
  const got = [];
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    got.push([Date.now() - t0, decoder.decode(value)]);
  }
  const problems = [];
  if (res.status !== 200) problems.push(`status ${res.status}`);
  const text = got.map(([, t]) => t).join("");
  if (text !== "chunk 1\nchunk 2\nchunk 3\nchunk 4\nchunk 5\n") problems.push(`body ${JSON.stringify(text)}`);
  const spread = got.length ? got[got.length - 1][0] - got[0][0] : 0;
  if (got.length < 2 || spread < 90) problems.push(`chunks arrived together: ${JSON.stringify(got)}`);
  report("stream: Response.stream sends chunks as they are written", problems, failures);

  const bp = await env.WORKER.fetch("http://test/stream/bp");
  const bpReader = bp.body.getReader();
  await bpReader.read();
  await sleep(300);
  const idle = await state(env);
  let total = 0;
  for (;;) {
    const { done, value } = await bpReader.read();
    if (done) break;
    total += value.length;
  }
  await sleep(50);
  const after = await state(env);
  const bpProblems = [];
  if (!(Number(idle.written) < 50)) bpProblems.push(`writer did not wait: written=${idle.written}`);
  if (after.written !== "50") bpProblems.push(`after drain written=${after.written}`);
  if (total < 49 * 65536) bpProblems.push(`bytes read after first read: ${total}`);
  report("stream: write waits for a slow reader", bpProblems, failures);

  const long = await env.WORKER.fetch("http://test/stream/cancel");
  const longReader = long.body.getReader();
  for (let i = 0; i < 3; i++) await longReader.read();
  await longReader.cancel("client gone");
  await sleep(200);
  const cancelled = await state(env);
  report(
    "stream: client cancel makes write raise Js_error",
    cancelled.ended === "Js_error" && Number(cancelled.written) < 1000 ? [] : [JSON.stringify(cancelled)],
    failures,
  );

  const bad = await env.WORKER.fetch("http://test/stream/raise");
  const badReader = bad.body.getReader();
  const first = decoder.decode((await badReader.read()).value);
  let rejected = "read did not reject";
  try {
    for (;;) if ((await badReader.read()).done) break;
  } catch (error) {
    rejected = "";
    if (!String(error).includes("boom")) rejected = `rejected with ${error}`;
  }
  const raiseProblems = [];
  if (first !== "before\n") raiseProblems.push(`first chunk ${JSON.stringify(first)}`);
  if (rejected) raiseProblems.push(rejected);
  report("stream: exception in the function aborts the body", raiseProblems, failures);
};

const echoCase = async (env, failures) => {
  let release;
  let gate = Promise.resolve();
  let n = 0;
  const body = new ReadableStream({
    async pull(controller) {
      await gate;
      if (n === 3) return controller.close();
      controller.enqueue(new TextEncoder().encode(`part ${++n}\n`));
      gate = new Promise((resolve) => (release = resolve));
    },
  });
  const res = await env.WORKER.fetch("http://test/stream/echo", {
    method: "POST",
    body,
    duplex: "half",
  });
  const reader = res.body.getReader();
  const got = [];
  const timeout = sleep(3000).then(() => "timeout");
  for (;;) {
    const next = await Promise.race([reader.read(), timeout]);
    if (next === "timeout" || next.done) {
      if (next === "timeout") got.push("timeout");
      break;
    }
    got.push(decoder.decode(next.value));
    release?.();
  }
  release?.();
  report(
    "stream: echo answers while the request body is still open",
    got.join("") === "part 1\npart 2\npart 3\n" ? [] : [JSON.stringify(got)],
    failures,
  );
};

const selfCloseCase = async (env, failures) => {
  const res = await env.WORKER.fetch("http://test/stream/self-close");
  const body = await res.text();
  await sleep(100);
  const { outcome } = await state(env);
  const problems = [];
  if (body !== "x") problems.push(`body ${JSON.stringify(body)}`);
  if (outcome !== "ok") problems.push(`fiber outcome ${outcome}`);
  report("stream: function that closes the writer itself ends cleanly", problems, failures);
};

const cacheCase = async (env, failures) => {
  const key = "http://test/cache-clone-key";
  const problems = [];
  try {
    const res = await env.WORKER.fetch("http://test/stream/cache-clone", { headers: { "x-key": key } });
    const body = await res.text();
    const cached = await (await env.WORKER.fetch(`http://test/cache/match?k=${encodeURIComponent(key)}`)).text();
    if (body !== "cached-body") problems.push(`returned ${JSON.stringify(body)}`);
    if (cached !== "200 yes cached-body") problems.push(`cached ${JSON.stringify(cached)}`);
  } catch (error) {
    problems.push(`threw ${error}`);
  }
  report("stream: Cache.put of a clone, then return the original", problems, failures);
};

const cases = [
  {
    name: "stream: iter cancels the source when the function raises",
    request: ["http://test/stream/iter-cancel"],
    status: 200,
    body: "cancelled",
  },
  {
    name: "response: empty has status, headers and no body",
    request: ["http://test/stream/empty"],
    status: 404,
    body: "",
    headers: { "x-a": "1", "content-type": null },
  },
  {
    name: "response: relative redirect",
    request: ["http://test/stream/redirect", { redirect: "manual" }],
    status: 307,
    headers: { location: "/login?x=1" },
  },
  {
    name: "response: absolute redirect",
    request: ["http://test/stream/redirect-abs", { redirect: "manual" }],
    status: 302,
    headers: { location: "http://test/login" },
  },
  {
    name: "response: of_stream passes an upstream body through",
    request: ["http://test/stream/pass", { method: "POST", body: new Uint8Array([0, 255, 10, 128]) }],
    status: 202,
    bodyBytes: [0, 255, 10, 128],
    headers: { "x-pass": "1" },
  },
  {
    name: "response: copy replaces headers and keeps the body",
    request: ["http://test/stream/copy"],
    status: 200,
    bodyBytes: [0, 255, 128, 10],
    headers: { "x-new": "1", "x-one": null },
  },
];

export default async (env, failures) => {
  await bodyCases(env, failures);
  await responseStreamCases(env, failures);
  await echoCase(env, failures);
  await selfCloseCase(env, failures);
  await cacheCase(env, failures);
  await runCases(env, cases, failures);
};
