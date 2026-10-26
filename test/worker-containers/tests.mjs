const cases = [
  ["a started container answers over its TCP port", "a/fetch", "running=true|hello-from-container\n"],
  ["running is true while the container runs", "a/fetch", "running=true|hello-from-container\n"],
  ["raw TCP connect round-trips an HTTP request to the container port", "t/tcp", " 200 OK|hello-from-container\n"],
  ["setInactivityTimeout is accepted and rejects 0", "o/timeout", "timeout=set|invalid|hello-from-container\n"],
  ["outbound HTTP of the container reaches the Worker through the interceptor", "i/intercept", "intercepted:/hi"],
  ["destroy stops the container", "a/destroy", "running=false"],
  ["monitor returns when the program exits", "m/monitor", "exited"],
  ["signal reaches the main process", "s/signal", "stopped"],
  ["destroy with a message makes monitor raise it", "d/destroy-message", "Error: bye"],
  ["exec runs a command with cwd and env and reports output and exit code", "e/exec", "out=hi:/tmp\n|err=oops\n|exit=3"],
  ["exec pipes stdin to the process", "x/exec-stdin", "ping"],
  ["inspect describes the running container", "n/inspect", "inspect=some|true"],
  ["a container snapshot restores the file system", "c/snapshot", "size>0=true|out=saved\n|err=|exit=0"],
  ["a directory snapshot restores the directory", "r/snapshot-dir", "out=kept\n|err=|exit=0"],
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
