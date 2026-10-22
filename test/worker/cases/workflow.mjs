import { report, sleep } from "./lib.mjs";

const call = async (env, path) => {
  const response = await env.WORKER.fetch(`http://test/workflow/${path}`);
  return { status: response.status, body: await response.text() };
};

const ok = async (env, path) => {
  const { status, body } = await call(env, path);
  if (status !== 200) throw new Error(`${path}: status ${status}: ${body}`);
  return JSON.parse(body);
};

const create = (env, id, params) =>
  ok(env, `create?id=${id}${params ? `&params=${encodeURIComponent(JSON.stringify(params))}` : ""}`);

const status = (env, id) => ok(env, `status?id=${id}`);

const until = async (env, id, wanted) => {
  let last;
  for (let i = 0; i < 200; i++) {
    last = await status(env, id);
    if (last.status === wanted) return last;
    await sleep(10);
  }
  throw new Error(`${id} never reached ${wanted}, last ${JSON.stringify(last)} ${JSON.stringify(await env.ENGINE.inspect(id))}`);
};

const check = async (name, failures, f) => {
  const problems = [];
  try {
    await f(problems);
  } catch (error) {
    problems.push(`threw ${error}`);
  }
  report(name, problems, failures);
};

const equal = (actual, expected, problems, what = "") => {
  if (JSON.stringify(actual) !== JSON.stringify(expected))
    problems.push(`${what}got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
};

const attempts = (inspected, name) => inspected.log.filter((e) => e.op === "do" && e.name === name).map((e) => e.attempt);

export default async (env, failures) => {
  await check("Workflow: a run gets the event, runs steps and returns its output", failures, async (p) => {
    equal(await create(env, "basic-1", { scenario: "basic", k: [1] }), "basic-1", p, "id: ");
    const done = await until(env, "basic-1", "complete");
    equal(
      done.output,
      {
        doubled: 42,
        payload: { scenario: "basic", k: [1] },
        instance_id: "basic-1",
        timestamp_is_recent: true,
        greeting: "from test config",
      },
      p,
    );
    const inspected = await env.ENGINE.inspect("basic-1");
    equal(inspected.runs, 1, p, "runs: ");
    equal([attempts(inspected, "first"), attempts(inspected, "double")], [[1], [1]], p, "attempts: ");
  });

  await check("Workflow: create without an id or params", failures, async (p) => {
    const id = await ok(env, "create");
    if (!String(id).startsWith("auto-")) p.push(`generated id ${id}`);
    equal((await until(env, id, "complete")).output.payload, { $undefined: true }, p);
  });

  await check("Workflow: sleep and sleep_until replay the run and do not repeat finished steps", failures, async (p) => {
    await create(env, "sleep-1", { scenario: "sleep" });
    equal((await until(env, "sleep-1", "complete")).output, ["b", "a"], p);
    const inspected = await env.ENGINE.inspect("sleep-1");
    equal(inspected.runs, 3, p, "runs: ");
    equal([attempts(inspected, "before"), attempts(inspected, "when"), attempts(inspected, "after")], [[1], [1], [1]], p, "callbacks: ");
    const nap = inspected.log.find((e) => e.op === "sleep");
    equal(nap.duration, 20, p, "sleep duration: ");
    const until_ = inspected.log.find((e) => e.op === "sleepUntil");
    if (typeof until_.timestamp !== "number" || until_.timestamp < 1e12) p.push(`sleepUntil timestamp ${until_.timestamp}`);
  });

  await check("Workflow: retries and timeout reach the runtime and a flaky step succeeds", failures, async (p) => {
    await create(env, "retry-1", { scenario: "retry" });
    equal((await until(env, "retry-1", "complete")).output, [1, 2, 3], p);
    const inspected = await env.ENGINE.inspect("retry-1");
    equal(attempts(inspected, "flaky"), [1, 2, 3], p, "attempts: ");
    equal(inspected.log[0].config, { retries: { limit: 3, delay: 1, backoff: "linear" }, timeout: 5000 }, p, "config: ");
  });

  await check("Workflow: a step that always fails raises Js_error in run after its retries", failures, async (p) => {
    await create(env, "exhausted-1", { scenario: "exhausted" });
    equal((await until(env, "exhausted-1", "complete")).output, "gave up", p);
    equal(attempts(await env.ENGINE.inspect("exhausted-1"), "always"), [1, 2], p, "attempts: ");
  });

  await check("Workflow: Non_retryable stops retries and fails the instance", failures, async (p) => {
    await create(env, "stop-1", { scenario: "stop" });
    const done = await until(env, "stop-1", "errored");
    equal(done.error.name, "NonRetryableError", p, "error name: ");
    if (!done.error.message.includes("do not retry")) p.push(`message ${done.error.message}`);
    equal(attempts(await env.ENGINE.inspect("stop-1"), "stop"), [1], p, "attempts: ");
  });

  await check("Workflow: run may catch a Non_retryable step failure and go on", failures, async (p) => {
    await create(env, "stop-2", { scenario: "stop_caught" });
    equal((await until(env, "stop-2", "complete")).output, ["recovered", true], p);
  });

  await check("Workflow: an exception in run errors the instance with its message", failures, async (p) => {
    await create(env, "fail-1", { scenario: "fail" });
    const done = await until(env, "fail-1", "errored");
    if (!done.error.message.includes("run failed")) p.push(`message ${done.error.message}`);
    equal(done.has_output, false, p, "has_output: ");
  });

  await check("Workflow: wait_for_event returns the payload of send_event", failures, async (p) => {
    await create(env, "event-1", { scenario: "event" });
    const waiting = await until(env, "event-1", "waiting");
    equal(waiting.has_output, false, p, "has_output: ");
    await ok(env, `send_event?id=event-1&type=approve&payload=${encodeURIComponent('{"ok":true}')}`);
    equal((await until(env, "event-1", "complete")).output, { approved: { ok: true } }, p);
    const inspected = await env.ENGINE.inspect("event-1");
    equal(inspected.log[0].options, { type: "approve" }, p, "options: ");
  });

  await check("Workflow: values with no JSON form survive a step result, an event payload and params", failures, async (p) => {
    const rich = (extra) => ({
      scenario: "rich",
      when: { $date: 86400000 },
      data: { $bytes: [0, 1, 255] },
      big: { $bigint: "12345678901234567890" },
      ...extra,
    });
    equal(await ok(env, "create?id=rich-1&rich=1"), "rich-1", p, "id: ");
    await until(env, "rich-1", "waiting");
    await ok(env, "send_event?id=rich-1&type=go&rich=1");
    const done = await until(env, "rich-1", "complete");
    equal(
      done.output,
      {
        step: {
          date: { $date: 172800000 },
          bytes: { $bytes: [0, 255] },
          map: { $map: [["k", { $set: [1] }]] },
          undefined: { $undefined: true },
        },
        payload: rich(),
        event: rich(),
      },
      p,
    );
  });

  await check("Workflow: a top-level Undefined survives as a step result, an event payload and params", failures, async (p) => {
    await create(env, "undef-1", { scenario: "undefined" });
    await until(env, "undef-1", "waiting");
    await ok(env, "send_event?id=undef-1&type=go&undefined=1");
    equal((await until(env, "undef-1", "complete")).output, { step: { $undefined: true }, event: { $undefined: true } }, p, "step and event: ");
    equal(await ok(env, "create?id=undef-2&undefined=1"), "undef-2", p, "id: ");
    equal((await until(env, "undef-2", "complete")).output.payload, { $undefined: true }, p, "payload: ");
  });

  await check("Workflow: wait_for_event timeout is passed and raises Js_error", failures, async (p) => {
    await create(env, "event-2", { scenario: "event_timeout" });
    equal((await until(env, "event-2", "complete")).output, "timed out", p);
    equal((await env.ENGINE.inspect("event-2")).log[0].options, { type: "approve", timeout: 30 }, p, "options: ");
  });

  await check("Workflow: invalid names and event types raise Invalid_argument in run", failures, async (p) => {
    await create(env, "invalid-1", { scenario: "invalid" });
    equal(
      (await until(env, "invalid-1", "complete")).output,
      [
        'Workero.Workflow.Step.wait_for_event: the event type "bad.type" must have only letters, digits, - and _',
        "Workero.Workflow.Step.sleep: the step name is longer than 256 characters",
      ],
      p,
    );
  });

  await check("Workflow: pause, resume", failures, async (p) => {
    await create(env, "pause-1", { scenario: "event" });
    await until(env, "pause-1", "waiting");
    await ok(env, "pause?id=pause-1");
    equal((await status(env, "pause-1")).status, "waiting_for_pause", p, "after pause: ");
    await ok(env, `send_event?id=pause-1&type=approve&payload=1`);
    await until(env, "pause-1", "paused");
    await ok(env, "resume?id=pause-1");
    equal((await until(env, "pause-1", "complete")).output, { approved: 1 }, p);
  });

  await check("Workflow: terminate", failures, async (p) => {
    await create(env, "term-1", { scenario: "event" });
    await until(env, "term-1", "waiting");
    await ok(env, "terminate?id=term-1");
    equal((await status(env, "term-1")).status, "terminated", p);
    const late = await call(env, "send_event?id=term-1&type=approve");
    equal(late.status, 502, p, "send_event status: ");
    if (!late.body.includes("not running")) p.push(`send_event body ${late.body}`);
  });

  await check("Workflow: restart runs the instance again", failures, async (p) => {
    await create(env, "restart-1", { scenario: "basic" });
    await until(env, "restart-1", "complete");
    await ok(env, "restart?id=restart-1");
    await until(env, "restart-1", "complete");
    equal((await env.ENGINE.inspect("restart-1")).runs, 2, p, "runs: ");
  });

  await check("Workflow: get finds an instance; a missing one and a duplicate id raise Js_error", failures, async (p) => {
    equal(await ok(env, "get?id=basic-1"), "basic-1", p);
    const missing = await call(env, "get?id=nope");
    equal(missing.status, 502, p, "missing status: ");
    if (!missing.body.includes("not_found")) p.push(`missing body ${missing.body}`);
    const duplicate = await call(env, "create?id=basic-1");
    equal(duplicate.status, 502, p, "duplicate status: ");
    if (!duplicate.body.includes("already_exists")) p.push(`duplicate body ${duplicate.body}`);
    const resume = await call(env, "resume?id=basic-1");
    equal(resume.status, 502, p, "resume status: ");
  });

  await check("Workflow: create rejects an id of more than 100 characters", failures, async (p) => {
    const { body } = await call(env, `create?id=${"x".repeat(101)}`);
    equal(body, "Invalid_argument Workero.Workflow.options: the instance id is longer than 100 characters", p);
  });

  await check("Workflow: create_batch returns the instances and the errors", failures, async (p) => {
    equal(await ok(env, "create_batch?ids=b1,b2,b1"), { created: ["b1", "b2"], errors: [{ index: 2, id: "b1", code: 10405 }] }, p);
    await until(env, "b1", "complete");
    await until(env, "b2", "complete");
  });

  await check("Workflow: of_env rejects a missing binding and one of another shape", failures, async (p) => {
    equal(await ok(env, "of_env_error?binding=NOPE"), 'Workero.Workflow.of_env: binding "NOPE" not found', p);
    equal(
      await ok(env, "of_env_error?binding=NOT_A_WORKFLOW"),
      'Workero.Workflow.of_env: binding "NOT_A_WORKFLOW" is an object without method create, not a Workflow binding',
      p,
    );
    equal(await ok(env, "of_env_error?binding=FLOW"), "ok", p);
  });
};
