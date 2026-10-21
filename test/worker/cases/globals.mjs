import { runCases } from "./lib.mjs";

const cases = [
  {
    name: "Timer.sleep waits",
    request: ["http://test/timer/sleep"],
    status: 200,
    check: (body) => (Number(body) >= 80 && Number(body) < 5000 ? undefined : `elapsed ${body} ms`),
  },
  { name: "Timer.set_timeout fires once", request: ["http://test/timer/set-timeout"], status: 200, body: "1" },
  { name: "Timer.clear_timeout prevents firing", request: ["http://test/timer/clear-timeout"], status: 200, body: "0" },
  {
    name: "Timer.set_interval repeats and clear_interval stops it",
    request: ["http://test/timer/interval"],
    status: 200,
    check: (body) => {
      const [stopped, final] = body.split(",").map(Number);
      if (!(stopped >= 3)) return `interval fired ${stopped} times before clear`;
      if (final !== stopped) return `count moved from ${stopped} to ${final} after clear`;
    },
  },
  {
    name: "Date.now is the current time",
    request: ["http://test/date/now"],
    status: 200,
    check: (body) => (Math.abs(Number(body) - Date.now()) < 10000 ? undefined : `now ${body}`),
  },
  {
    name: "Date.to_iso_string",
    request: ["http://test/date/iso"],
    status: 200,
    body: "1970-01-01T00:00:00.000Z;2023-11-14T22:13:20.123Z;invalid",
  },
  {
    name: "Crypto.random_uuid",
    request: ["http://test/crypto/uuid"],
    status: 200,
    check: (body) => {
      const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
      const [a, b] = body.split(",");
      if (!uuid.test(a) || !uuid.test(b)) return `not version 4 UUIDs: ${body}`;
      if (a === b) return "two UUIDs are equal";
    },
  },
  {
    name: "Crypto.random_bytes",
    request: ["http://test/crypto/bytes"],
    status: 200,
    body: "0,1,16,65536;differ=true;nonzero=true;invalid;invalid",
  },
  { name: "Console.log levels do not throw", request: ["http://test/console/log"], status: 200, body: "logged" },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
