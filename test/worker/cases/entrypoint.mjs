import { report, runCases } from "./lib.mjs";

const call = (method, args, binding = "CALC") => [
  `http://test/entrypoint/call?binding=${binding}&method=${method}&args=${encodeURIComponent(JSON.stringify(args))}`,
];

const ocamlCases = [
  { name: "Entrypoint.call: OCaml calls an entrypoint method with two arguments", request: call("add", [2, 3]), status: 200, body: "5" },
  { name: "Entrypoint.call: the handler reads the env of the entrypoint", request: call("greet", ["Ana"]), status: 200, body: '"from test config, Ana"' },
  { name: "Entrypoint.call: JSON arguments reach the handler and come back", request: call("echo", [1, "a", { k: [null, true] }]), status: 200, body: '[1,"a",{"k":[null,true]}]' },
  { name: "Entrypoint.call: a method that returns nothing gives null", request: call("nothing", []), status: 200, body: "null" },
  { name: "Entrypoint.call: a handler may await", request: call("slow", []), status: 200, body: '"after await"' },
  { name: "Entrypoint.call: a handler may call another service", request: call("ask_backend", []), status: 200, body: '"GET|/x|null|"' },
  { name: "Entrypoint.call: a raising handler raises Js_error in the caller", request: call("fail", []), status: 502, bodyIncludes: "calc failed" },
  { name: "Entrypoint.call: a missing method raises Js_error", request: call("nope", []), status: 502, bodyIncludes: "nope" },
  { name: "Entrypoint.call: a handler rejects wrong arguments", request: call("add", ["a", 1]), status: 502, bodyIncludes: "expected an int" },
  { name: "Entrypoint.call: the handler gets the ctx and may call wait_until", request: call("background", []), status: 200, body: '"scheduled"' },
  { name: "Entrypoint.call: a JavaScript method that returns undefined gives null", request: call("nothing", [], "JSRPC"), status: 200, body: "null" },
  { name: "Entrypoint.call: a JavaScript method returns an object", request: call("object", [], "JSRPC"), status: 200, body: '{"a":[1,2],"b":null}' },
  { name: "Entrypoint.call: an asynchronous JavaScript method is awaited", request: call("delayed", [[1, "x"]], "JSRPC"), status: 200, body: '[1,"x"]' },
  { name: "Entrypoint.call: a result with no JSON form raises Invalid_argument", request: call("big", [], "JSRPC"), status: 200, bodyIncludes: "Invalid_argument Workero.JSON.of_js" },
  { name: "Entrypoint.call: a class named like a reserved word works", request: call("ping", [], "CLASSEP"), status: 200, body: '"pong"' },
];

const check = async (name, failures, f) => {
  const problems = [];
  try {
    await f(problems);
  } catch (error) {
    problems.push(`threw ${error}`);
  }
  report(name, problems, failures);
};

const rejects = async (promise, text, problems) => {
  try {
    await promise;
    problems.push("did not reject");
  } catch (error) {
    if (!String(error).includes(text)) problems.push(`rejected with ${error}, expected ${text}`);
  }
};

const equal = (actual, expected, problems) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected))
    problems.push(`got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
};

export default async (env, failures) => {
  await runCases(env, ocamlCases, failures);
  await check("Entrypoint: JavaScript calls an OCaml method", failures, async (p) => equal(await env.CALC.add(2, 3), 5, p));
  await check("Entrypoint: JavaScript gets the env of the entrypoint", failures, async (p) => equal(await env.CALC.greet("Bo"), "from test config, Bo", p));
  await check("Entrypoint: JSON values round-trip", failures, async (p) => {
    const value = [1, "a", { k: [null, true], n: 1.5 }];
    equal(await env.CALC.echo(...value), value, p);
  });
  await check("Entrypoint: a method that returns nothing gives null", failures, async (p) => equal(await env.CALC.nothing(), null, p));
  await check("Entrypoint: a handler may await", failures, async (p) => equal(await env.CALC.slow(), "after await", p));
  await check("Entrypoint: calls run in parallel", failures, async (p) =>
    equal(await Promise.all([env.CALC.add(1, 1), env.CALC.slow(), env.CALC.add(2, 2)]), [2, "after await", 4], p),
  );
  await check("Entrypoint: a raising handler rejects the call", failures, async (p) => rejects(env.CALC.fail(), "calc failed", p));
  await check("Entrypoint: a missing method rejects", failures, async (p) => rejects(env.CALC.nope(), "nope", p));
  await check("Entrypoint: wrong arguments reject", failures, async (p) => rejects(env.CALC.add("a", 1), "expected an int", p));
  await check("Entrypoint: the fetch handler answers requests", failures, async (p) => {
    const response = await env.CALC.fetch("http://x/path");
    equal(await response.text(), "calc fetch /path", p);
  });
  await check("Entrypoint: a declared method on a class with no rpc handler fails", failures, async (p) =>
    rejects(env.NORPC.declared(), "have no ~rpc", p),
  );
  await check("Entrypoint: a class named like a reserved word works", failures, async (p) => equal(await env.CLASSEP.ping(), "pong", p));
};
