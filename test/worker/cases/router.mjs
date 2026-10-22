import { runCases } from "./lib.mjs";

const cases = [
  { name: "router: int parameter", request: ["http://test/router/users/42"], status: 200, body: "user 42" },
  { name: "router: static beats parameter", request: ["http://test/router/users/me"], status: 200, body: "me" },
  { name: "router: int parameter must parse", request: ["http://test/router/users/abc"], status: 400 },
  {
    name: "router: POST route",
    request: ["http://test/router/users/7", { method: "POST", body: "hi" }],
    status: 200,
    body: "7 hi",
  },
  {
    name: "router: 405 lists the methods",
    request: ["http://test/router/users/7", { method: "DELETE" }],
    status: 405,
    headers: { allow: "GET, POST" },
  },
  { name: "router: catch-all joins decoded segments", request: ["http://test/router/files/a/b%20c/d"], status: 200, body: "file a/b c/d" },
  { name: "router: catch-all needs a segment", request: ["http://test/router/files"], status: 404 },
  { name: "router: parameter is percent-decoded", request: ["http://test/router/name/caf%C3%A9"], status: 200, body: "name café" },
  { name: "router: encoded slash is rejected", request: ["http://test/router/name/a%2Fb"], status: 400 },
  { name: "router: not found", request: ["http://test/router/nothing"], status: 404, body: "Not Found" },
  {
    name: "router: trailing slash redirects, query kept",
    request: ["http://test/router/name/x/?a=1", { redirect: "manual" }],
    status: 308,
    headers: { location: "/router/name/x?a=1" },
  },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
