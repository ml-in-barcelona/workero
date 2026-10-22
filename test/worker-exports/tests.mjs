const exported = async (call) => {
  try {
    const result = await call();
    return result?.outcome === undefined || result.outcome === "ok";
  } catch {
    return false;
  }
};

export default {
  async test(_controller, env) {
    const fetch = await exported(() => env.WORKER.fetch("http://test/"));
    const scheduled = await exported(() =>
      env.WORKER.scheduled({ cron: "* * * * *", scheduledTime: 0 }),
    );
    const queue = await exported(() =>
      env.WORKER.queue("jobs", [{ id: "m1", timestamp: new Date(0), body: "x", attempts: 1 }]),
    );
    const email = (await (await env.PROBE.fetch("http://probe/")).json()).includes("email");
    const actual = [fetch && "fetch", scheduled && "scheduled", queue && "queue", email && "email"]
      .filter(Boolean)
      .join("+");
    if (actual !== env.EXPECT)
      throw new Error(`exports ${JSON.stringify(actual)}, expected ${JSON.stringify(env.EXPECT)}`);
    console.log(`ok - exports ${actual}`);
  },
};
