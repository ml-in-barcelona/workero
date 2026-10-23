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
  {
    name: "Ai.run passes every gateway option as the options argument",
    request: ["http://test/ai/run-gateway?model=@test/options"],
    status: 200,
    body: JSON.stringify({
      options: {
        gateway: {
          id: "my-gateway",
          cacheKey: "k",
          cacheTtl: 60,
          skipCache: false,
          collectLog: true,
          eventId: "e1",
          requestTimeoutMs: 5000,
          retries: { maxAttempts: 3, retryDelayMs: 100, backoff: "exponential" },
          metadata: { user: "u1", n: 2, ok: true, none: null },
        },
      },
    }),
  },
  {
    name: "Ai.gateway with only an id sends only the id",
    request: ["http://test/ai/run-gateway-id?model=@test/options"],
    status: 200,
    body: '{"options":{"gateway":{"id":"plain"}}}',
  },
  {
    name: "Ai.run without a gateway passes no options",
    request: ["http://test/ai/run?model=@test/options"],
    status: 200,
    body: '{"options":null}',
  },
  {
    name: "Ai.run_bytes accepts a gateway",
    request: ["http://test/ai/run-bytes-gateway?model=@test/bytes"],
    status: 200,
    body: "5",
  },
  {
    name: "Ai.run_stream sets stream and returns the chunks of the stream",
    request: ["http://test/ai/run-stream?model=@test/stream-echo"],
    status: 200,
    body: 'data: {"input":{"stream":true,"prompt":"hi","n":[1,null]},"options":null}\n\ndata: [DONE]\n\n',
  },
  {
    name: "Ai.run_stream replaces a stream field of the input",
    request: ["http://test/ai/run-stream-replace?model=@test/stream-echo"],
    status: 200,
    body: 'data: {"input":{"stream":true,"p":1},"options":null}\n\ndata: [DONE]\n\n',
  },
  {
    name: "Ai.run_stream passes the gateway",
    request: ["http://test/ai/run-stream-gateway?model=@test/stream-echo"],
    status: 200,
    bodyIncludes: '"options":{"gateway":{"id":"my-gateway","cacheKey":"k"',
  },
  {
    name: "Ai.run_stream raises Invalid_argument when the model does not answer with a stream",
    request: ["http://test/ai/run-stream?model=@test/echo"],
    status: 200,
    body: "invalid: Workero.Ai.run_stream: the model did not answer with a stream",
  },
  {
    name: "Ai.run_stream raises Invalid_argument for an input that is not an object",
    request: ["http://test/ai/run-stream-bad-input?model=@test/stream-echo"],
    status: 200,
    body: "invalid: Workero.Ai.run_stream: the input must be a JSON object",
  },
  {
    name: "Ai.gateway and Ai.retries reject invalid values",
    request: ["http://test/ai/bad-options"],
    status: 200,
    body: [
      "invalid: Workero.Ai.gateway: a metadata value must be null, a boolean, a number or a string",
      "invalid: Workero.Ai.retries: max_attempts 6 is outside 1 to 5",
    ].join("\n"),
  },
  { name: "Ai.of_env rejects a variable", request: ["http://test/ai/shape?model=GREETING"], status: 200, body: shape("GREETING", "is a string, not a Workers AI binding") },
  { name: "Ai.of_env of a missing binding", request: ["http://test/ai/shape?model=NOPE"], status: 200, body: shape("NOPE", "not found") },
  { name: "Ai.of_env accepts the binding", request: ["http://test/ai/shape?model=AI"], status: 200, body: "ok" },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
