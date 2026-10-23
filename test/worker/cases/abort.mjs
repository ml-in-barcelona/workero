import { report, runCases, sleep } from "./lib.mjs";

const cases = [
  {
    name: "abort: fetch ~signal stops when a controller aborts",
    request: ["http://test/abort/fetch-controller"],
    status: 200,
    body: "raised abort=true AbortError: The operation was aborted fast=true",
  },
  {
    name: "abort: abort ~reason gives an AbortError with that message",
    request: ["http://test/abort/fetch-reason"],
    status: 200,
    body: "raised abort=true AbortError: because fast=true",
  },
  {
    name: "abort: Abort_signal.timeout makes fetch raise a TimeoutError",
    request: ["http://test/abort/fetch-timeout"],
    status: 200,
    body: "raised abort=true TimeoutError: The operation was aborted due to timeout fast=true",
  },
  {
    name: "abort: a signal that does not abort changes nothing",
    request: ["http://test/abort/fetch-unaborted"],
    status: 200,
    body: "status 203",
  },
  {
    name: "abort: Abort_signal.any follows the timeout",
    request: ["http://test/abort/fetch-any"],
    status: 200,
    body: "raised abort=true TimeoutError: The operation was aborted due to timeout fast=true",
  },
  {
    name: "abort: Abort_signal.any follows the controller",
    request: ["http://test/abort/fetch-any-controller"],
    status: 200,
    body: "raised abort=true AbortError: The operation was aborted fast=true",
  },
  {
    name: "abort: a signal cancels reading the response body",
    request: ["http://test/abort/fetch-body"],
    status: 200,
    bodyIncludes: "raised abort=true AbortError",
    check: (body) => (body.endsWith("fast=true") ? undefined : `slow: ${body}`),
  },
  {
    name: "abort: an aborted signal fails fetch without a request",
    request: ["http://test/abort/fetch-immediate"],
    status: 200,
    body: "raised abort=true AbortError: The operation was aborted fast=true reached=0",
  },
  {
    name: "abort: to_promise ends a race",
    request: ["http://test/abort/race"],
    status: 200,
    body: "raised abort=true AbortError: The operation was aborted fast=true",
  },
  {
    name: "abort: on_abort runs in a fiber that can await",
    request: ["http://test/abort/on-abort"],
    status: 200,
    body: "before=unset right_after=unset final=after await",
  },
  {
    name: "abort: on_abort of an aborted signal still runs",
    request: ["http://test/abort/on-abort-late"],
    status: 200,
    body: "ran",
  },
  {
    name: "abort: on_abort runs once when abort is called twice",
    request: ["http://test/abort/on-abort-once"],
    status: 200,
    body: "1",
  },
  {
    name: "abort: an exception in an on_abort function does not stop the handler",
    request: ["http://test/abort/on-abort-raises"],
    status: 200,
    body: "survived",
  },
  {
    name: "abort: aborted, reason and throw_if_aborted",
    request: ["http://test/abort/state"],
    status: 200,
    body: "aborted=false reason=none | no raise | aborted=true reason=AbortError: stop | raised abort=true AbortError: stop",
  },
  {
    name: "abort: is_abort is false for other errors",
    request: ["http://test/abort/is-abort-other"],
    status: 200,
    body: "false false",
  },
  {
    name: "abort: Fetcher.fetch ~signal stops a service binding call",
    request: ["http://test/abort/fetcher"],
    status: 200,
    body: "raised abort=true AbortError: The operation was aborted fast=true",
  },
  {
    name: "abort: Fetcher.fetch_request ~signal stops the call and keeps the request signal",
    request: ["http://test/abort/fetcher-request/slow"],
    status: 200,
    body: "raised abort=true AbortError: The operation was aborted fast=true own_aborted=false",
  },
  {
    name: "abort: Fetcher.fetch_request ~signal forwards the request",
    request: ["http://test/abort/fetcher-request/echo"],
    status: 200,
    body: "status 200",
  },
  {
    name: "abort: Request.signal has not aborted for a live request",
    request: ["http://test/abort/request-signal"],
    status: 200,
    body: "aborted=false",
  },
];

const disconnectCase = async (env, failures) => {
  const controller = new AbortController();
  const res = await env.WORKER.fetch("http://test/abort/disconnect", { signal: controller.signal });
  const reader = res.body.getReader();
  await reader.read();
  controller.abort();
  await reader.read().catch(() => {});
  await sleep(200);
  const state = await (await env.WORKER.fetch("http://test/abort/disconnect-state")).text();
  report("abort: Request.signal fires when the client cancels a streamed response", state === "signal" ? [] : [state], failures);
};

export default async (env, failures) => {
  await runCases(env, cases, failures);
  await disconnectCase(env, failures);
};
