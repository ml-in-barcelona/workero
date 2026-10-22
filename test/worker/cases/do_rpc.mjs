import { report, runCases } from "./lib.mjs";

const viaOcaml = (binding, name, method, args) => [
  `http://test/do-rpc/${binding}/${name}/${method}` + (args === undefined ? "" : `?args=${encodeURIComponent(JSON.stringify(args))}`),
];

const check = async (name, failures, f) => {
  const problems = [];
  try {
    const problem = await f();
    if (problem !== undefined) problems.push(problem);
  } catch (error) {
    problems.push(`threw ${error}`);
  }
  report(name, problems, failures);
};

const expect = (actual, expected) =>
  JSON.stringify(actual) === JSON.stringify(expected) ? undefined : `got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`;

const expectThrows = async (promise, text) => {
  try {
    await promise;
  } catch (error) {
    return String(error).includes(text) ? undefined : `threw ${error}, expected a message with ${JSON.stringify(text)}`;
  }
  return "did not throw";
};

export default async (env, failures) => {
  const stub = env.RPC.get(env.RPC.idFromName("js"));

  await check("RPC from JavaScript: a method without arguments returns its result", failures, async () => expect(await stub.increment(), 1));
  await check("RPC from JavaScript: the object keeps its state between calls", failures, async () => expect(await stub.increment(), 2));
  await check("RPC from JavaScript: arguments reach the method", failures, async () => expect(await stub.add(40, 2), 42));
  await check("RPC from JavaScript: a JSON value round-trips", failures, async () =>
    expect(await stub.echo({ a: [1, null, "x"], b: { c: true } }), { a: [1, null, "x"], b: { c: true } }));
  await check("RPC from JavaScript: a method that returns unit gives null", failures, async () => expect(await stub.nothing(), null));
  await check("RPC from JavaScript: a method may suspend", failures, async () => expect(await stub.slow(), "slept"));
  await check("RPC from JavaScript: an OCaml exception rejects the call with its message", failures, async () =>
    expectThrows(stub.fail("kaboom"), "kaboom"));
  await check("RPC from JavaScript: an undeclared method is not found", failures, async () =>
    expectThrows(stub.missing(), 'does not implement the method "missing"'));
  await check("RPC from JavaScript: a class whose handlers have no rpc fails the call", failures, async () => {
    const bare = env.RPC_NO_HANDLER.get(env.RPC_NO_HANDLER.idFromName("bare"));
    return expectThrows(bare.ping(), "have no ~rpc");
  });

  await runCases(
    env,
    [
      { name: "RPC from OCaml: Durable_object.call returns the result", request: viaOcaml("RPC", "ocaml", "add", [20, 22]), status: 200, body: "42" },
      { name: "RPC from OCaml: a call changes the state of the object", request: viaOcaml("RPC", "ocaml", "increment"), status: 200, body: "1" },
      { name: "RPC from OCaml: the next call sees the state", request: viaOcaml("RPC", "ocaml", "increment"), status: 200, body: "2" },
      { name: "RPC from OCaml: a JSON value round-trips", request: viaOcaml("RPC", "ocaml", "echo", [{ a: [1, null] }]), status: 200, body: '{"a":[1,null]}' },
      { name: "RPC from OCaml: a method that returns unit gives `Null", request: viaOcaml("RPC", "ocaml", "nothing"), status: 200, body: "null" },
      { name: "RPC from OCaml: a method may suspend", request: viaOcaml("RPC", "ocaml", "slow"), status: 200, body: '"slept"' },
      { name: "RPC from OCaml: an exception raises Js_error with its message", request: viaOcaml("RPC", "ocaml", "fail", ["kaboom"]), status: 502, bodyIncludes: "kaboom" },
      { name: "RPC from OCaml: an undeclared method raises Js_error", request: viaOcaml("RPC", "ocaml", "missing"), status: 502, bodyIncludes: "does not implement" },
    ],
    failures,
  );

  const shared = env.RPC.get(env.RPC.idFromName("shared"));
  await check("RPC: JavaScript and OCaml reach the same object", failures, async () => {
    await shared.increment();
    const response = await env.WORKER.fetch(...viaOcaml("RPC", "shared", "get"));
    const body = await response.text();
    return expect(body, "1") ?? expect(await shared.increment(), 2);
  });
};
