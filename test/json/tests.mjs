const JSON_TYPE = "application/json; charset=utf-8";
const post = (path, body) => [
  `http://test${path}`,
  { method: "POST", body },
];

const cases = [
  {
    name: "echo valid JSON",
    request: post("/json", '{"a":[1,2.5,null,true],"b":{"c":"d"}}'),
    status: 200,
    body: '{"a":[1,2.5,null,true],"b":{"c":"d"}}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "unicode round trip",
    request: post("/json", '{"s":"héllo ñ 日本語 😀 \\u00e9"}'),
    status: 200,
    body: '{"s":"héllo ñ 日本語 😀 é"}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "invalid JSON",
    request: post("/json", '{"a":'),
    status: 400,
    body: '{"error":"Line 1, bytes 4-5:\\nUnexpected end of input"}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "empty body",
    request: post("/json", ""),
    status: 400,
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "decode a record, ignore extra fields",
    request: post("/user", '{"name":"Ana","age":30,"extra":1}'),
    status: 200,
    body: '{"name":"Ana","age":30}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "decode type mismatch",
    request: post("/user", '{"name":"Ana","age":"x"}'),
    status: 422,
    body: '{"error":"expected int but got string: \\"x\\""}',
  },
  {
    name: "decode invalid JSON",
    request: post("/user", "nope"),
    status: 422,
  },
  {
    name: "uncaught parse error",
    request: post("/raise", "{bad"),
    throws: "Of_string_error",
  },
  {
    name: "custom status and headers",
    request: ["http://test/custom"],
    status: 201,
    body: "[1,null]",
    headers: { "content-type": "application/vnd.api+json", "x-a": "b" },
  },
  { name: "unknown route", request: ["http://test/nope"], status: 404 },
];

const report = (name, problems, failures) => {
  if (problems.length) failures.push(`${name}: ${problems.join("; ")}`);
  console.log(`${problems.length ? "FAIL" : "ok"} - ${name}`);
};

export default {
  async test(_controller, env) {
    const failures = [];
    for (const c of cases) {
      const problems = [];
      let response;
      let body;
      try {
        response = await env.WORKER.fetch(...c.request);
        body = await response.text();
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
        problems.push(
          `body ${JSON.stringify(body)}, expected ${JSON.stringify(c.body)}`,
        );
      for (const [k, v] of Object.entries(c.headers ?? {}))
        if (response.headers.get(k) !== v)
          problems.push(
            `header ${k} is ${response.headers.get(k)}, expected ${v}`,
          );
      report(c.name, problems, failures);
    }
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
