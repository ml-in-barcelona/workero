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

  await check("Workflow: wait_for_event returns the event that send_event sent", failures, async (p) => {
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

  const rollbacks = (inspected) => inspected.log.filter((e) => e.op === "rollback");

  await check("Workflow: do_ gives the step name, count, attempt and retry configuration", failures, async (p) => {
    await create(env, "ctx-1", { scenario: "ctx" });
    equal(
      (await until(env, "ctx-1", "complete")).output,
      [
        { name: "ctx", count: 1, attempt: 1, limit: 4, backoff: "linear" },
        { name: "ctx", count: 2, attempt: 1, limit: 5, backoff: "exponential" },
        { name: "plain", count: 1, attempt: 1, limit: 5, backoff: "exponential" },
      ],
      p,
    );
  });

  await check("Workflow: retries_with computes the delay of each retry from the failed attempt", failures, async (p) => {
    await create(env, "delay-1", { scenario: "delay_fn" });
    equal((await until(env, "delay-1", "complete")).output, 3, p);
    const inspected = await env.ENGINE.inspect("delay-1");
    equal(inspected.log.filter((e) => e.op === "delay").map((e) => e.delay), [1011, 1012], p, "delays: ");
    equal(attempts(inspected, "flaky"), [1, 2, 3], p, "attempts: ");
  });

  await check("Workflow: rollback handlers run in reverse order when the instance fails", failures, async (p) => {
    await create(env, "rollback-1", { scenario: "rollback" });
    await until(env, "rollback-1", "errored");
    const ran = rollbacks(await env.ENGINE.inspect("rollback-1"));
    equal(ran.map((e) => e.name), ["b", "a"], p, "order: ");
    if (!ran[0]?.threw?.includes("undo b B")) p.push(`handler b saw ${ran[0]?.threw}`);
    if (!ran[1]?.threw?.includes("undo a A")) p.push(`handler a saw ${ran[1]?.threw}`);
    if (!ran[0]?.threw?.includes("stop here")) p.push(`handler b error ${ran[0]?.threw}`);
    equal(ran.map((e) => e.config), [{ timeout: 5000 }, undefined], p, "rollback config: ");
  });

  await check("Workflow: terminate ~rollback:true runs the rollback handlers, and terminate does not", failures, async (p) => {
    await create(env, "rbw-1", { scenario: "rollback_wait" });
    await create(env, "rbw-2", { scenario: "rollback_wait" });
    await until(env, "rbw-1", "waiting");
    await until(env, "rbw-2", "waiting");
    await ok(env, "terminate?id=rbw-1&rollback=true");
    await ok(env, "terminate?id=rbw-2");
    equal((await status(env, "rbw-1")).status, "terminated", p, "rbw-1: ");
    const ran = rollbacks(await env.ENGINE.inspect("rbw-1"));
    equal(ran.map((e) => e.name), ["a"], p, "rolled back: ");
    if (!ran[0]?.threw?.includes("undo a")) p.push(`handler saw ${ran[0]?.threw}`);
    equal(rollbacks(await env.ENGINE.inspect("rbw-2")), [], p, "without rollback: ");
  });

  await check("Workflow: restart ~from keeps the results of the steps before it", failures, async (p) => {
    await create(env, "from-1", { scenario: "steps" });
    equal((await until(env, "from-1", "complete")).output, [1, 2, 3], p);
    await ok(env, "restart?id=from-1&from=two&count=2");
    await until(env, "from-1", "complete");
    const reran = (await env.ENGINE.inspect("from-1")).log.filter((e) => e.op === "do").map((e) => `${e.name}:${e.count}`);
    equal(reran, ["two:2"], p, "steps run again: ");
    await ok(env, "restart?id=from-1&from=nap&kind=sleep");
    await until(env, "from-1", "complete");
    equal((await env.ENGINE.inspect("from-1")).log.filter((e) => e.op === "do").map((e) => `${e.name}:${e.count}`), ["two:2"], p, "from a sleep: ");
    const none = await call(env, "restart?id=from-1&from=nap&kind=do");
    equal(none.status, 502, p, "no matching kind: ");
    if (!none.body.includes("no step matches")) p.push(`body ${none.body}`);
    const bad = await call(env, "restart?id=from-1&from=two&count=0");
    equal(bad.body, "Invalid_argument Workero.Workflow.Instance.restart_from: count is below 1", p, "count 0: ");
  });

  await check("Workflow: wait_for_event returns the type, payload and timestamp of the event", failures, async (p) => {
    await create(env, "evf-1", { scenario: "event_full" });
    await until(env, "evf-1", "waiting");
    await ok(env, `send_event?id=evf-1&type=approve&payload=${encodeURIComponent('{"ok":true}')}`);
    equal((await until(env, "evf-1", "complete")).output, { type: "approve", payload: { ok: true }, recent: true }, p);
  });

  await check("Workflow: retention reaches the runtime", failures, async (p) => {
    await ok(env, "create?id=ret-1&success=1000&error=2000");
    await ok(env, "create?id=ret-2&success=1000");
    await ok(env, "create?id=ret-3");
    equal((await env.ENGINE.inspect("ret-1")).retention, { successRetention: 1000, errorRetention: 2000 }, p, "both: ");
    equal((await env.ENGINE.inspect("ret-2")).retention, { successRetention: 1000 }, p, "success only: ");
    equal((await env.ENGINE.inspect("ret-3")).retention, undefined, p, "none: ");
  });

  await check("Workflow: create_batch_count starts that many instances with the same params and retention", failures, async (p) => {
    const params = encodeURIComponent(JSON.stringify({ scenario: "basic", k: 7 }));
    const batch = await ok(env, `create_batch_count?count=3&params=${params}&success=500`);
    equal(batch.created.length, 3, p, "created: ");
    equal(batch.errors, 0, p, "errors: ");
    equal(new Set(batch.created).size, 3, p, "distinct ids: ");
    for (const id of batch.created) {
      equal((await until(env, id, "complete")).output.payload, { scenario: "basic", k: 7 }, p, `${id} payload: `);
      equal((await env.ENGINE.inspect(id)).retention, { successRetention: 500 }, p, `${id} retention: `);
    }
    equal((await call(env, "create_batch_count?count=0")).body, "Invalid_argument Workero.Workflow.create_batch_count: count must be in 1..100", p, "count 0: ");
    equal((await call(env, "create_batch_count?count=101")).body, "Invalid_argument Workero.Workflow.create_batch_count: count must be in 1..100", p, "count 101: ");
  });

  await check("Workflow: Instance.delete removes the instance", failures, async (p) => {
    await create(env, "del-1", { scenario: "basic" });
    await until(env, "del-1", "complete");
    await ok(env, "delete?id=del-1");
    const gone = await call(env, "get?id=del-1");
    equal(gone.status, 502, p, "get after delete: ");
    if (!gone.body.includes("not_found")) p.push(`get body ${gone.body}`);
    equal((await call(env, "delete?id=del-1")).status, 502, p, "second delete: ");
  });

  await check("Workflow: delete_batch returns the ids deleted and the errors", failures, async (p) => {
    await create(env, "del-2", { scenario: "basic" });
    await create(env, "del-3", { scenario: "event" });
    equal(
      await ok(env, "delete_batch?ids=del-2,del-3,nope"),
      { deleted: ["del-2", "del-3"], errors: [{ id: "nope", code: 10400 }] },
      p,
    );
    equal((await call(env, "get?id=del-3")).status, 502, p, "running instance gone: ");
    equal((await call(env, "delete_batch?ids=")).body, "Invalid_argument Workero.Workflow.delete_batch: the number of ids must be in 1..100", p, "no ids: ");
  });

  await check("Workflow: the event has the workflow name and no schedule for a direct instance", failures, async (p) => {
    equal(await ok(env, "create?binding=FULL&id=full-1"), "full-1", p, "id: ");
    equal(
      (await until(env, "full-1", "complete")).output,
      { workflow_name: "test-flow", instance_id: "full-1", payload: { $undefined: true }, schedule: null },
      p,
    );
  });

  await check("Workflow: the event has the cron schedule of a scheduled instance", failures, async (p) => {
    await env.FULL_ENGINE.triggerCron({ id: "cron-1" }, "0 * * * *", 1700000000000);
    equal((await until(env, "cron-1", "complete")).output.schedule, { cron: "0 * * * *", scheduled_time: 1700000000000 }, p);
  });
};
