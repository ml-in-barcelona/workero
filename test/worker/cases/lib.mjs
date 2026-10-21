export const sameBytes = (actual, expected) =>
  actual.length === expected.length && expected.every((b, i) => actual[i] === b);

export const report = (name, problems, failures) => {
  if (problems.length) failures.push(`${name}: ${problems.join("; ")}`);
  console.log(`${problems.length ? "FAIL" : "ok"} - ${name}`);
};

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export const runCases = async (env, cases, failures) => {
  for (const c of cases) {
    const problems = [];
    let response;
    let body;
    let bytes;
    try {
      response = await env.WORKER.fetch(...c.request);
      bytes = new Uint8Array(await response.arrayBuffer());
      body = new TextDecoder().decode(bytes);
    } catch (error) {
      if (c.throws === undefined || !String(error).includes(c.throws))
        problems.push(`threw ${error}`);
      report(c.name, problems, failures);
      continue;
    }
    if (c.throws !== undefined) problems.push("did not throw");
    if (response.status !== c.status)
      problems.push(`status ${response.status}, expected ${c.status}`);
    if (c.body !== undefined && body !== c.body)
      problems.push(`body ${JSON.stringify(body)}, expected ${JSON.stringify(c.body)}`);
    if (c.bodyIncludes !== undefined && !body.includes(c.bodyIncludes))
      problems.push(`body ${JSON.stringify(body)} lacks ${JSON.stringify(c.bodyIncludes)}`);
    if (c.bodyBytes !== undefined && !sameBytes(bytes, c.bodyBytes))
      problems.push(`bytes ${[...bytes]}, expected ${c.bodyBytes}`);
    if (c.check !== undefined) {
      const problem = c.check(body);
      if (problem !== undefined) problems.push(problem);
    }
    for (const [k, v] of Object.entries(c.headers ?? {}))
      if (response.headers.get(k) !== v)
        problems.push(`header ${k} is ${response.headers.get(k)}, expected ${v}`);
    report(c.name, problems, failures);
  }
};
