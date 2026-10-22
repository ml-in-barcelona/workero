import { runCases } from "./lib.mjs";

const shape = (name, found) => `Workero.Ai.of_env: binding "${name}" ${found}`;

const cases = [
  {
    name: "Ai.run sends the model and the JSON input, and decodes the JSON answer",
    request: ["http://test/ai/run?model=@test/echo"],
    status: 200,
    body: '{"model":"@test/echo","input":{"prompt":"hi","n":[1,null]}}',
  },
  {
    name: "Ai.run raises Js_error for an unknown model",
    request: ["http://test/ai/run?model=@test/missing"],
    status: 200,
    bodyIncludes: "js_error: Error: no such model: @test/missing",
  },
  {
    name: "Ai.run raises Invalid_argument for a stream answer",
    request: ["http://test/ai/run?model=@test/stream"],
    status: 200,
    body: "invalid: Workero.Ai.run: the model answered with a stream",
  },
  {
    name: "Ai.run raises Invalid_argument for an answer without a JSON form",
    request: ["http://test/ai/run?model=@test/undefined"],
    status: 200,
    body: "invalid: Workero.JSON.of_js: the value has no JSON form",
  },
  { name: "Ai.run_bytes returns the raw bytes", request: ["http://test/ai/run-bytes?model=@test/bytes"], status: 200, body: "1,2,3,0,255" },
  {
    name: "Ai.run_bytes raises Invalid_argument for a JSON answer",
    request: ["http://test/ai/run-bytes?model=@test/echo"],
    status: 200,
    body: "invalid: Workero.Decode: expected bytes, got object",
  },
  { name: "Ai.of_env rejects a variable", request: ["http://test/ai/shape?model=GREETING"], status: 200, body: shape("GREETING", "is a string, not a Workers AI binding") },
  { name: "Ai.of_env of a missing binding", request: ["http://test/ai/shape?model=NOPE"], status: 200, body: shape("NOPE", "not found") },
  { name: "Ai.of_env accepts the binding", request: ["http://test/ai/shape?model=AI"], status: 200, body: "ok" },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
