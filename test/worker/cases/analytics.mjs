import { runCases, report } from "./lib.mjs";

const shape = (name, found) => `Workero.Analytics_engine.of_env: binding "${name}" ${found}`;

const writes = [
  {
    name: "Analytics_engine.write sends the index, doubles and blobs",
    path: "/analytics/full",
    point: {
      keys: ["indexes", "doubles", "blobs"],
      indexes: ["user-1"],
      doubles: [1.5, 2, -3],
      blobs: ["page", { buffer: true, bytes: [0, 255, 128] }],
    },
  },
  {
    name: "Analytics_engine.write without arguments sends no index",
    path: "/analytics/empty",
    point: { keys: ["doubles", "blobs"], doubles: [], blobs: [] },
  },
  {
    name: "Analytics_engine.write sends an index alone",
    path: "/analytics/index-only",
    point: { keys: ["indexes", "doubles", "blobs"], indexes: ["only"], doubles: [], blobs: [] },
  },
];

const runWrites = async (env, failures) => {
  let count = 0;
  for (const w of writes) {
    const problems = [];
    const response = await env.WORKER.fetch(`http://test${w.path}`);
    const body = await response.text();
    if (response.status !== 200 || body !== "written") problems.push(`status ${response.status} body ${JSON.stringify(body)}`);
    count += 1;
    const all = await (await env.WORKER.fetch("http://test/analytics/points")).json();
    if (all.length !== count) problems.push(`${all.length} points, expected ${count}`);
    if (JSON.stringify(all[count - 1]) !== JSON.stringify(w.point))
      problems.push(`point ${JSON.stringify(all[count - 1])}, expected ${JSON.stringify(w.point)}`);
    report(w.name, problems, failures);
  }
};

const cases = [
  { name: "Analytics_engine.write raises Js_error when the binding throws", request: ["http://test/analytics/raises"], status: 502, bodyIncludes: "too many blobs" },
  { name: "Analytics_engine.of_env rejects a variable", request: ["http://test/analytics/shape?name=GREETING"], status: 200, body: shape("GREETING", "is a string, not an Analytics Engine dataset") },
  { name: "Analytics_engine.of_env of a missing binding", request: ["http://test/analytics/shape?name=NOPE"], status: 200, body: shape("NOPE", "not found") },
  { name: "Analytics_engine.of_env accepts the binding", request: ["http://test/analytics/shape?name=ANALYTICS"], status: 200, body: "ok" },
];

export default async (env, failures) => {
  await runWrites(env, failures);
  await runCases(env, cases, failures);
};
