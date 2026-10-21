import { report, sameBytes, sleep } from "./lib.mjs";

const connect = async (env, path) => {
  const res = await env.WORKER.fetch(`http://test${path}`, { headers: { Upgrade: "websocket" } });
  const ws = res.webSocket;
  if (!ws) throw new Error(`no webSocket, status ${res.status}`);
  ws.accept();
  ws.binaryType = "arraybuffer";
  const events = [];
  let wake = () => {};
  const push = (e) => {
    events.push(e);
    wake();
  };
  ws.addEventListener("message", (e) =>
    push(typeof e.data === "string" ? { type: "text", data: e.data } : { type: "binary", data: new Uint8Array(e.data) }),
  );
  ws.addEventListener("close", (e) => push({ type: "close", code: e.code, reason: e.reason }));
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

const wsCase = async (name, failures, body) => {
  const problems = [];
  try {
    await body(problems);
  } catch (error) {
    problems.push(`threw ${error}`);
  }
  report(name, problems, failures);
};

const expect = (problems, label, actual, expected) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected))
    problems.push(`${label} ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
};

export default async (env, failures) => {
  await wsCase("ws: text echo with an await before send", failures, async (problems) => {
    const { ws, next } = await connect(env, "/ws/echo");
    ws.send("hello");
    expect(problems, "reply", await next(), { type: "text", data: "hello" });
    ws.close(1000, "done");
    await next();
  });

  await wsCase("ws: slow then fast replies stay in order", failures, async (problems) => {
    const { ws, next } = await connect(env, "/ws/echo");
    ws.send("slow");
    ws.send("fast");
    ws.send("fast2");
    const got = [await next(), await next(), await next()].map((e) => e.data);
    expect(problems, "replies", got, ["slow", "fast", "fast2"]);
    ws.close(1000, "done");
    await next();
  });

  await wsCase("ws: binary echo", failures, async (problems) => {
    const { ws, next } = await connect(env, "/ws/echo");
    ws.send(new Uint8Array([0, 1, 255]));
    const e = await next();
    if (e.type !== "binary" || !sameBytes(e.data, [0, 1, 255])) problems.push(`reply ${JSON.stringify(e)}`);
    ws.close(1000, "done");
    await next();
  });

  await wsCase("ws: client close gives Close and receive repeats it", failures, async (problems) => {
    const { ws, next } = await connect(env, "/ws/echo");
    ws.close(1000, "bye");
    await next();
    let outcome = "";
    for (let i = 0; i < 60 && outcome === ""; i++) {
      outcome = await (await env.WORKER.fetch("http://test/ws/outcome")).text();
      if (outcome === "") await sleep(50);
    }
    expect(problems, "outcome", outcome, "1000:bye:same");
  });

  await wsCase("ws: server close reaches the client with its code", failures, async (problems) => {
    const { next } = await connect(env, "/ws/server-close");
    expect(problems, "first", await next(), { type: "text", data: "hi" });
    expect(problems, "close", await next(), { type: "close", code: 4001, reason: "server says" });
  });

  await wsCase("ws: send after close raises Js_error", failures, async (problems) => {
    const { next } = await connect(env, "/ws/server-close");
    await next();
    await next();
    const res = await env.WORKER.fetch("http://test/ws/outcome");
    expect(problems, "outcome", await res.text(), "Js_error");
  });

  await wsCase("ws: a second concurrent receive raises Invalid_argument", failures, async (problems) => {
    const { next } = await connect(env, "/ws/two-receives");
    expect(problems, "close", (await next()).type, "close");
    const res = await env.WORKER.fetch("http://test/ws/outcome");
    expect(problems, "outcome", await res.text(), "Invalid_argument");
  });

  await wsCase("ws: upgrade closes with 1011 when the function raises", failures, async (problems) => {
    const { next } = await connect(env, "/ws/raise");
    const e = await next();
    expect(problems, "close", [e.type, e.code], ["close", 1011]);
  });
};
