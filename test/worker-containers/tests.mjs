const cases = [
  ["a started container answers over its TCP port", "a/fetch", "running=true|hello-from-container\n"],
  ["running is true while the container runs", "a/fetch", "running=true|hello-from-container\n"],
  ["destroy stops the container", "a/destroy", "running=false"],
  ["monitor returns when the program exits", "m/monitor", "exited"],
  ["signal reaches the main process", "s/signal", "stopped"],
  ["destroy with a message makes monitor raise it", "d/destroy-message", "Error: bye"],
];

export default {
  async test(_controller, env) {
    const failures = [];
    for (const [name, path, expected] of cases) {
      const problems = [];
      try {
        const body = await (await env.WORKER.fetch("http://test/" + path)).text();
        if (!body.includes(expected.trimEnd())) problems.push(`body ${JSON.stringify(body)} lacks ${JSON.stringify(expected)}`);
      } catch (error) {
        problems.push(`threw ${error}`);
      }
      if (problems.length) failures.push(`${name}: ${problems.join("; ")}`);
      console.log(`${problems.length ? "FAIL" : "ok"} - ${name}`);
    }
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
