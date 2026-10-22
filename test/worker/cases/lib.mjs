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

export const rpcValues = [
  ["undefined", undefined, "undefined"],
  ["null", null, "null"],
  ["bool", true, "boolean"],
  ["int", 42, "number"],
  ["float", 1.5, "number"],
  ["nan", NaN, "number"],
  ["negative zero", -0, "number"],
  ["string", "héllo", "string"],
  ["list", [1, "a", null], "Array"],
  ["object", { a: 1 }, "Object"],
  ["bytes", new Uint8Array([0, 1, 255]), "Uint8Array"],
  ["empty bytes", new Uint8Array(0), "Uint8Array"],
  ["date", new Date(86400000), "Date"],
  ["bigint", 123456789012345678901234567890n, "bigint"],
  ["negative bigint", -5n, "bigint"],
  [
    "map",
    new Map([
      [1, "a"],
      ["k", [new Date(0)]],
    ]),
    "Map",
  ],
  ["set", new Set([1, "x"]), "Set"],
  ["nested", { a: [undefined, new Date(5)], b: new Map([["k", new Set([1n])]]) }, "Object"],
];

export const canon = (v) => {
  if (v === undefined) return "undefined";
  if (typeof v === "bigint") return `${v}n`;
  if (typeof v === "number") return Object.is(v, -0) ? "-0" : String(v);
  if (v === null || typeof v !== "object") return JSON.stringify(v);
  if (v instanceof Uint8Array) return `bytes[${[...v]}]`;
  if (v instanceof Date) return `date(${v.getTime()})`;
  if (v instanceof Map) return `map{${[...v].map(([k, x]) => `${canon(k)}=>${canon(x)}`)}}`;
  if (v instanceof Set) return `set{${[...v].map(canon)}}`;
  if (Array.isArray(v)) return `[${v.map(canon)}]`;
  return `{${Object.entries(v).map(([k, x]) => `${k}:${canon(x)}`)}}`;
};
