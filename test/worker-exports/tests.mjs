const exported = async (call) => {
  try {
    await call();
    return true;
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
    const actual = [fetch && "fetch", scheduled && "scheduled"].filter(Boolean).join("+");
    if (actual !== env.EXPECT)
      throw new Error(`exports ${JSON.stringify(actual)}, expected ${JSON.stringify(env.EXPECT)}`);
    console.log(`ok - exports ${actual}`);
  },
};
