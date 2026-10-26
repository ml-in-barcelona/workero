import { WorkerEntrypoint, RpcTarget } from "cloudflare:workers";

const instances = new Map();
let counter = 0;
const SCALE_MS = 5;

const STEP_TYPES = { do: "do", sleep: "sleep", sleepUntil: "sleep", wait: "waitForEvent" };
const DEFAULT_CONFIG = { retries: { limit: 5, delay: 10000, backoff: "exponential" }, timeout: 600000 };

const STOPPED = Symbol("stopped");

class Evict extends Error {}
class Stopped extends Error {}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const nonRetryable = (e) => e?.name === "NonRetryableError" || String(e?.message).startsWith("NonRetryableError");

class Step extends RpcTarget {
  #inst;
  #run;
  #counts = new Map();
  constructor(inst, run) {
    super();
    this.#inst = inst;
    this.#run = run;
  }
  #next(kind, name) {
    const key = `${kind}:${name}`;
    const count = (this.#counts.get(key) ?? 0) + 1;
    this.#counts.set(key, count);
    const full = `${key}:${count}`;
    if (!this.#inst.order.some((o) => o.key === full)) this.#inst.order.push({ key: full, type: STEP_TYPES[kind], name, count });
    return { key: full, count };
  }
  async #enter() {
    const inst = this.#inst;
    while (inst.paused) {
      inst.parked = true;
      await wait(2);
    }
    inst.parked = false;
    if (inst.run !== this.#run || inst.stopped) throw new Stopped("stopped");
  }
  async do(name, ...rest) {
    await this.#enter();
    const callbackIndex = rest.findIndex((a) => typeof a === "function");
    const callback = rest[callbackIndex];
    const config = callbackIndex > 0 ? rest[0] : {};
    const rollback = rest[callbackIndex + 1];
    const inst = this.#inst;
    const { key, count } = this.#next("do", name);
    const cached = inst.cache.get(key);
    if (cached?.error) throw cached.error;
    if (cached) return cached.value;
    const resolved = { ...DEFAULT_CONFIG, ...config, retries: { ...DEFAULT_CONFIG.retries, ...config.retries } };
    const limit = resolved.retries.limit;
    const dynamic = typeof resolved.retries.delay === "function";
    const shown = dynamic ? { ...resolved, retries: { ...resolved.retries, delay: null } } : resolved;
    for (let attempt = 1; ; attempt++) {
      inst.log.push({ op: "do", name, count, attempt, config: dynamic ? { ...config, retries: { ...config.retries, delay: null } } : config });
      const ctx = { attempt, step: { name, count }, config: shown };
      try {
        const value = await callback(ctx);
        inst.cache.set(key, { value });
        if (rollback?.rollback) inst.rollbacks.push({ name, count, ctx, output: value, handler: rollback.rollback.dup(), config: rollback.rollbackConfig });
        return value;
      } catch (e) {
        if (nonRetryable(e) || attempt > limit) {
          inst.cache.set(key, { error: e });
          throw e;
        }
        const delay = dynamic ? await resolved.retries.delay({ ctx, error: e }) : resolved.retries.delay;
        inst.log.push({ op: "delay", name, count, attempt, delay });
        await wait(1);
      }
    }
  }
  async #settle(inst, key, ms) {
    await wait(Math.min(ms, SCALE_MS * 4));
    inst.cache.set(key, { value: true });
    throw new Evict("evicted");
  }
  async sleep(name, duration) {
    await this.#enter();
    const inst = this.#inst;
    const { key, count } = this.#next("sleep", name);
    inst.log.push({ op: "sleep", name, count, duration });
    if (inst.cache.has(key)) return;
    inst.status = "waiting";
    await this.#settle(inst, key, typeof duration === "number" ? duration : 1);
  }
  async sleepUntil(name, timestamp) {
    await this.#enter();
    const inst = this.#inst;
    const { key, count } = this.#next("sleepUntil", name);
    inst.log.push({ op: "sleepUntil", name, count, timestamp: Number(timestamp) });
    if (inst.cache.has(key)) return;
    inst.status = "waiting";
    await this.#settle(inst, key, Number(timestamp) - Date.now());
  }
  async waitForEvent(name, options) {
    await this.#enter();
    const inst = this.#inst;
    const { key, count } = this.#next("wait", name);
    inst.log.push({ op: "waitForEvent", name, count, options });
    const cached = inst.cache.get(key);
    if (cached?.error) throw cached.error;
    if (cached) return cached.value;
    const queued = inst.events.get(options.type)?.shift();
    if (queued) {
      inst.cache.set(key, { value: queued });
      return queued;
    }
    inst.status = "waiting";
    const timeout = typeof options.timeout === "number" ? options.timeout : 24 * 3600 * 1000;
    const event = await Promise.race([
      new Promise((resolve) => {
        const list = inst.waiters.get(options.type) ?? [];
        list.push(resolve);
        inst.waiters.set(options.type, list);
      }),
      wait(Math.min(timeout, 60000)).then(() => null),
      new Promise((resolve) => {
        inst.wakeStop = () => resolve(STOPPED);
      }),
    ]);
    inst.wakeStop = undefined;
    if (event === STOPPED) throw new Stopped("stopped");
    if (event === null) {
      const error = new Error(`Execution timed out after ${timeout}ms`);
      inst.cache.set(key, { error });
      inst.status = "running";
      throw error;
    }
    inst.cache.set(key, { value: event });
    throw new Evict("evicted");
  }
}

const rollBack = async (inst, error) => {
  const pending = inst.rollbacks.splice(0).reverse();
  for (const r of pending) {
    const entry = { op: "rollback", name: r.name, count: r.count, output: r.output, config: r.config, error: { name: error?.name ?? "Error", message: String(error?.message ?? error) } };
    inst.log.push(entry);
    try {
      await r.handler({ ctx: r.ctx, error, output: r.output });
    } catch (e) {
      entry.threw = String(e?.message ?? e);
    }
  }
};

const execute = async (inst, workflow) => {
  const run = ++inst.run;
  inst.status = "running";
  for (;;) {
    inst.runs++;
    try {
      const output = await workflow.run(
        { payload: inst.params, timestamp: inst.createdAt, instanceId: inst.id, workflowName: "test-flow", schedule: inst.schedule },
        new Step(inst, run),
      );
      if (inst.run === run && !inst.stopped) {
        inst.output = output;
        inst.status = "complete";
      }
      return;
    } catch (e) {
      if (inst.run !== run || inst.stopped) {
        if (inst.run === run && inst.rollbackOnStop) {
          inst.rollbackOnStop = false;
          await rollBack(inst, new Error("instance terminated"));
        }
        inst.stopDone?.();
        return;
      }
      if (String(e?.message).includes("evicted")) {
        inst.status = "running";
        continue;
      }
      inst.error = { name: e?.name ?? "Error", message: String(e?.message ?? e) };
      await rollBack(inst, e);
      inst.status = "errored";
      return;
    }
  }
};

const fresh = (id, params, extra = {}) => ({
  id,
  params,
  ...extra,
  order: [],
  rollbacks: [],
  createdAt: new Date(),
  status: "queued",
  output: undefined,
  error: undefined,
  cache: new Map(),
  log: [],
  runs: 0,
  run: 0,
  paused: false,
  parked: false,
  stopped: false,
  events: new Map(),
  waiters: new Map(),
});

const find = (id) => {
  const inst = instances.get(id);
  if (!inst) throw new Error(`instance.not_found: ${id}`);
  return inst;
};

export class Engine extends WorkerEntrypoint {
  get workflow() {
    return this.env.USER_WORKFLOW;
  }
  #start(options, extra) {
    const id = options?.id ?? `auto-${++counter}`;
    if (instances.has(id)) throw new Error(`instance.already_exists: ${id}`);
    const inst = fresh(id, options?.params, { retention: options?.retention, ...extra });
    instances.set(id, inst);
    this.ctx.waitUntil(execute(inst, this.workflow));
    return { id };
  }
  create(options) {
    return this.#start(options);
  }
  triggerCron(options, cron, scheduledTime) {
    return this.#start(options, { schedule: { cron, scheduledTime } });
  }
  createBatch(options) {
    const created = [];
    const errors = [];
    const seen = new Set();
    const list = options.count !== undefined ? Array.from({ length: options.count }, () => ({ params: options.params, retention: options.retention })) : (options.instances ?? []);
    if (list.length < 1 || list.length > 100) throw new Error("createBatch: expected 1 to 100 instances");
    list.forEach((o, index) => {
      if (o.id !== undefined && instances.has(o.id)) errors.push({ index, id: o.id, code: 10405, message: "instance already exists" });
      else if (o.id !== undefined && seen.has(o.id)) errors.push({ index, id: o.id, code: 10415, message: "duplicate id in batch" });
      else {
        if (o.id !== undefined) seen.add(o.id);
        created.push(this.#start(o));
      }
    });
    return { created, errors };
  }
  async deleteBatch(ids) {
    if (ids.length < 1 || ids.length > 100) throw new Error("deleteBatch: expected 1 to 100 ids");
    const deleted = [];
    const errors = [];
    for (const id of ids) {
      if (!instances.has(id)) errors.push({ id, code: 10400, message: `instance.not_found: ${id}` });
      else {
        this.#remove(find(id));
        deleted.push({ id });
      }
    }
    return { deleted, errors };
  }
  #remove(inst) {
    inst.stopped = true;
    inst.paused = false;
    inst.rollbacks.length = 0;
    instances.delete(inst.id);
  }
  delete(id) {
    this.#remove(find(id));
  }
  get(id) {
    find(id);
    return { id };
  }
  status(id) {
    const inst = find(id);
    const status = inst.paused ? (inst.parked ? "paused" : "waitingForPause") : inst.status;
    const out = { status };
    if (inst.error) out.error = inst.error;
    if (inst.output !== undefined) out.output = inst.output;
    return out;
  }
  pause(id) {
    const inst = find(id);
    inst.paused = true;
  }
  resume(id) {
    const inst = find(id);
    if (!inst.paused) throw new Error("instance is already running");
    inst.paused = false;
  }
  async terminate(id, options) {
    const inst = find(id);
    if (["errored", "terminated", "complete"].includes(inst.status)) throw new Error(`instance is ${inst.status}`);
    inst.stopped = true;
    inst.paused = false;
    if (options?.rollback) {
      inst.rollbackOnStop = true;
      let finished = false;
      inst.stopDone = () => {
        finished = true;
      };
      inst.wakeStop?.();
      while (!finished) await wait(2);
    }
    inst.status = "terminated";
  }
  restart(id, options) {
    const inst = find(id);
    const from = options?.from;
    let keep = [];
    if (from) {
      const count = from.count ?? 1;
      const index = inst.order.findIndex((o) => o.name === from.name && o.count === count && (from.type === undefined || o.type === from.type));
      if (index < 0) throw new Error(`restart: no step matches ${JSON.stringify(from)}`);
      keep = inst.order.slice(0, index);
    }
    const kept = new Set(keep.map((o) => o.key));
    inst.stopped = false;
    inst.cache = new Map([...inst.cache].filter(([key]) => kept.has(key)));
    inst.rollbacks = inst.rollbacks.filter((r) => kept.has(`do:${r.name}:${r.count}`));
    inst.order = keep;
    inst.log = [];
    inst.events = new Map();
    inst.waiters = new Map();
    inst.output = undefined;
    inst.error = undefined;
    inst.paused = false;
    this.ctx.waitUntil(execute(inst, this.workflow));
  }
  sendEvent(id, event) {
    const inst = find(id);
    if (["complete", "errored", "terminated"].includes(inst.status))
      throw new Error("instance is not running");
    const value = { type: event.type, payload: event.payload, timestamp: new Date() };
    const waiter = inst.waiters.get(event.type)?.shift();
    if (waiter) return waiter(value);
    const list = inst.events.get(event.type) ?? [];
    list.push(value);
    inst.events.set(event.type, list);
  }
  inspect(id) {
    const inst = find(id);
    return { runs: inst.runs, retention: inst.retention, log: JSON.parse(JSON.stringify(inst.log)) };
  }
}

export class FullEngine extends Engine {
  get workflow() {
    return this.env.USER_FULL;
  }
}

export default {
  fetch() {
    return new Response("workflow engine");
  },
};
