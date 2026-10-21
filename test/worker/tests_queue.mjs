import queue from "./cases/queue.mjs";

export default {
  async test(_controller, env) {
    const failures = [];
    await queue(env, failures);
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
