import { WorkerEntrypoint, RpcTarget } from "cloudflare:workers";

const instances = new Map();
let counter = 0;
const SCALE_MS = 5;

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
    return { key: `${key}:${count}`, count };
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
    const callback = rest.at(-1);
    const config = rest.length > 1 ? rest[0] : {};
    const inst = this.#inst;
    const { key, count } = this.#next("do", name);
    const cached = inst.cache.get(key);
    if (cached?.error) throw cached.error;
    if (cached) return cached.value;
    const limit = config.retries?.limit ?? 5;
    for (let attempt = 1; ; attempt++) {
      inst.log.push({ op: "do", name, count, attempt, config });
      try {
        const value = await callback({ attempt, step: { name, count }, config });
        inst.cache.set(key, { value });
        return value;
      } catch (e) {
        if (nonRetryable(e) || attempt > limit) {
          inst.cache.set(key, { error: e });
          throw e;
        }
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
    ]);
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

const execute = async (inst, env) => {
  const run = ++inst.run;
  inst.status = "running";
  for (;;) {
    inst.runs++;
    try {
      const output = await env.USER_WORKFLOW.run(
        { payload: inst.params, timestamp: inst.createdAt, instanceId: inst.id },
        new Step(inst, run),
      );
      if (inst.run === run && !inst.stopped) {
        inst.output = output;
        inst.status = "complete";
      }
      return;
    } catch (e) {
      if (inst.run !== run || inst.stopped) return;
      if (String(e?.message).includes("evicted")) {
        inst.status = "running";
        continue;
      }
      inst.error = { name: e?.name ?? "Error", message: String(e?.message ?? e) };
      inst.status = "errored";
      return;
    }
  }
};

const fresh = (id, params) => ({
  id,
  params,
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
  #start(options) {
    const id = options?.id ?? `auto-${++counter}`;
    if (instances.has(id)) throw new Error(`instance.already_exists: ${id}`);
    const inst = fresh(id, options?.params);
    instances.set(id, inst);
    this.ctx.waitUntil(execute(inst, this.env));
    return { id };
  }
  create(options) {
    return this.#start(options);
  }
  createBatch(options) {
    const created = [];
    const errors = [];
    (options.instances ?? []).forEach((o, index) => {
      if (o.id !== undefined && instances.has(o.id))
        errors.push({ index, id: o.id, code: 10405, message: "instance already exists" });
      else created.push(this.#start(o));
    });
    return { created, errors };
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
  terminate(id) {
    const inst = find(id);
    inst.stopped = true;
    inst.status = "terminated";
    inst.paused = false;
  }
  restart(id) {
    const inst = find(id);
    inst.stopped = false;
    inst.cache = new Map();
    inst.log = [];
    inst.events = new Map();
    inst.waiters = new Map();
    inst.output = undefined;
    inst.error = undefined;
    inst.paused = false;
    this.ctx.waitUntil(execute(inst, this.env));
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
    return { runs: inst.runs, log: JSON.parse(JSON.stringify(inst.log)) };
  }
}

export default {
  fetch() {
    return new Response("workflow engine");
  },
};
