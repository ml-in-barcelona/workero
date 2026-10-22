import { runCases } from "./lib.mjs";

const cases = [
  { name: "Fetcher.fetch sends a GET to a service binding", request: ["http://test/fetcher/get"], status: 200, body: "200|echo|GET|/echo?x=1|null|" },
  {
    name: "Fetcher.fetch sends the method, headers and body",
    request: ["http://test/fetcher/post"],
    status: 200,
    body: "200|echo|POST|/echo|from ocaml|payload",
  },
  { name: "Fetcher.fetch sends raw bytes", request: ["http://test/fetcher/bytes"], status: 200, body: "200|none|00ff800a" },
  { name: "Fetcher.fetch returns a non-200 response", request: ["http://test/fetcher/status"], status: 200, body: "418|teapot|short and stout" },
  {
    name: "Fetcher.fetch_request forwards the method, path, headers and body",
    request: ["http://test/fetcher/forward?q=2", { method: "PATCH", headers: { "x-a": "client" }, body: "client body" }],
    status: 200,
    body: "200|echo|PATCH|/fetcher/forward?q=2|client|client body",
  },
  {
    name: "Fetcher.fetch_request of a clone keeps the original body readable",
    request: ["http://test/fetcher/forward-clone", { method: "POST", body: "twice" }],
    status: 200,
    body: "twice||200|echo|POST|/fetcher/forward-clone|null|twice",
  },
  {
    name: "Fetcher.fetch raises Js_error when the target raises",
    request: ["http://test/fetcher/raises"],
    status: 502,
    bodyIncludes: "backend boom",
  },
  {
    name: "Fetcher.of_env of a variable",
    request: ["http://test/fetcher/shape?name=GREETING"],
    status: 200,
    body: 'Workero.Fetcher.of_env: binding "GREETING" is a string, not a service binding or an assets binding',
  },
  {
    name: "Fetcher.of_env of a missing binding",
    request: ["http://test/fetcher/shape?name=NOPE"],
    status: 200,
    body: 'Workero.Fetcher.of_env: binding "NOPE" not found',
  },
  {
    name: "Fetcher.of_env of a KV namespace",
    request: ["http://test/fetcher/shape?name=KV"],
    status: 200,
    body: 'Workero.Fetcher.of_env: binding "KV" is an object without method fetch, not a service binding or an assets binding',
  },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
