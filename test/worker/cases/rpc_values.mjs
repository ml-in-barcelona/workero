import { canon, report, rpcValues, runCases } from "./lib.mjs";

const targets = ["do", "entrypoint", "js-entrypoint", "js-do"];
const via = (target, scenario) => [`http://test/rpc-values/${target}/${scenario}`];

const echoBody = rpcValues.map(([label]) => `${label}: ok`).join("\n");
const kindsBody = rpcValues.map(([label, , kind]) => `${label}: ${kind}`).join("\n");

const ocamlCases = targets.flatMap((target) => [
  { name: `RPC values, OCaml to ${target}: every value type round-trips`, request: via(target, "echo"), status: 200, body: echoBody },
  { name: `RPC values, OCaml to ${target}: the callee sees the JavaScript type`, request: via(target, "kinds"), status: 200, body: kindsBody },
  { name: `RPC values, OCaml to ${target}: functions cross in both directions`, request: via(target, "functions"), status: 200, body: "call_fn: int 42\nmake_fn: int 2" },
  { name: `RPC values, OCaml to ${target}: streams cross in both directions`, request: via(target, "streams"), status: 200, body: 'stream_text: "xyz123"\nmake_stream: "abcdef"' },
  {
    name: `RPC values, OCaml to ${target}: stubs cross in both directions`,
    request: via(target, "stubs"),
    status: 200,
    body: "service: calc fetch /p\ndurable object: rpc object\ngive_stub: GET|/p|null|",
  },
]);

const check = async (name, failures, f) => {
  const problems = [];
  try {
    await f(problems);
  } catch (error) {
    problems.push(`threw ${error}`);
  }
  report(name, problems, failures);
};

const equal = (actual, expected, problems) => {
  if (actual !== expected) problems.push(`got ${actual}, expected ${expected}`);
};

const readText = async (stream) => await new Response(stream).text();

const fromJavaScript = async (name, getTarget, env, failures) => {
    for (const [label, value, kind] of rpcValues) {
      await check(`RPC values, JavaScript to ${name}: ${label} round-trips`, failures, async (p) => equal(canon(await getTarget().same(value)), canon(value), p));
      await check(`RPC values, JavaScript to ${name}: ${label} is read as ${kind}`, failures, async (p) => equal(await getTarget().kind(value), kind, p));
    }
    await check(`RPC values, JavaScript to ${name}: an ArrayBuffer is read as bytes`, failures, async (p) =>
      equal(canon(await getTarget().same(new Uint8Array([7, 8]).buffer)), "bytes[7,8]", p),
    );
    await check(`RPC values, JavaScript to ${name}: a view of a larger buffer keeps its range`, failures, async (p) =>
      equal(canon(await getTarget().same(new Uint8Array([1, 2, 3, 4]).subarray(1, 3))), "bytes[2,3]", p),
    );
    await check(`RPC values, JavaScript to ${name}: OCaml calls a function of the caller`, failures, async (p) =>
      equal(await getTarget().call_fn((x) => x * 2, 21), 42, p),
    );
    await check(`RPC values, JavaScript to ${name}: OCaml returns a function`, failures, async (p) => {
      const f = await getTarget().make_fn();
      equal(await f(1), 2, p);
    });
    await check(`RPC values, JavaScript to ${name}: OCaml reads a stream of the caller`, failures, async (p) => {
      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode("xyz"));
          controller.enqueue(new TextEncoder().encode("123"));
          controller.close();
        },
      });
      equal(await getTarget().stream_text(stream), "xyz123", p);
    });
    await check(`RPC values, JavaScript to ${name}: OCaml returns a stream`, failures, async (p) =>
      equal(await readText(await getTarget().make_stream()), "abcdef", p),
    );
    await check(`RPC values, JavaScript to ${name}: OCaml fetches through a service stub`, failures, async (p) =>
      equal(await getTarget().stub_text(env.CALC), "calc fetch /p", p),
    );
    await check(`RPC values, JavaScript to ${name}: OCaml fetches through a Durable Object stub`, failures, async (p) =>
      equal(await getTarget().stub_text(env.RPC.get(env.RPC.idFromName("values"))), "rpc object", p),
    );
    await check(`RPC values, JavaScript to ${name}: OCaml returns a stub`, failures, async (p) => {
      const stub = await getTarget().give_stub();
      equal(await (await stub.fetch("http://x/p")).text(), "GET|/p|null|", p);
    });
};

export default async (env, failures) => {
  await runCases(env, ocamlCases, failures);
  await fromJavaScript("a Durable Object", () => env.RPC.get(env.RPC.idFromName("values")), env, failures);
  await fromJavaScript("an entrypoint", () => env.CALC, env, failures);
};
