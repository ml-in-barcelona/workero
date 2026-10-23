import queue from "./cases/queue.mjs";
import { events } from "./cases/entrypoint.mjs";

export default {
  async test(_controller, env) {
    const failures = [];
    await queue(env, failures);
    await events(env, failures);
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
