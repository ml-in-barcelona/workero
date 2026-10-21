import { runCases } from "./lib.mjs";

const shape = (name, found) => `Workero.Rate_limiter.of_env: binding "${name}" ${found}`;

const cases = [
  { name: "Rate_limiter.limit allows until the limit, then denies", request: ["http://test/rate-limiter/limit?key=alpha"], status: 200, body: "true,true,false" },
  { name: "Rate_limiter.limit counts each key on its own", request: ["http://test/rate-limiter/limit?key=beta"], status: 200, body: "true,true,false" },
  { name: "Rate_limiter.limit continues the count of a key", request: ["http://test/rate-limiter/limit?key=beta"], status: 200, body: "false,false,false" },
  { name: "Rate_limiter.limit raises Js_error when the binding throws", request: ["http://test/rate-limiter/raises"], status: 502, bodyIncludes: "limiter unavailable" },
  { name: "Rate_limiter.of_env rejects a variable", request: ["http://test/rate-limiter/shape?key=GREETING"], status: 200, body: shape("GREETING", "is a string, not a rate limiter") },
  { name: "Rate_limiter.of_env of a missing binding", request: ["http://test/rate-limiter/shape?key=NOPE"], status: 200, body: shape("NOPE", "not found") },
  { name: "Rate_limiter.of_env accepts the binding", request: ["http://test/rate-limiter/shape?key=LIMITER"], status: 200, body: "ok" },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
