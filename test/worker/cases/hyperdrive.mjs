import { runCases } from "./lib.mjs";

const shape = (name, found) => `Workero.Hyperdrive.of_env: binding "${name}" ${found}`;

const field = (text, name) => text.split("\n").find((l) => l.startsWith(`${name}=`))?.slice(name.length + 1);

const cases = [
  {
    name: "Hyperdrive gives the user and the database of the binding",
    request: ["http://test/hyperdrive/details"],
    status: 200,
    check: (body) =>
      field(body, "user") === "alice" && field(body, "database") === "app"
        ? undefined
        : `user or database wrong in ${JSON.stringify(body)}`,
  },
  {
    name: "Hyperdrive gives a host, the port and the password",
    request: ["http://test/hyperdrive/details"],
    status: 200,
    check: (body) => {
      if (!field(body, "host")) return "empty host";
      if (field(body, "port") !== "5432") return `port ${field(body, "port")}`;
      if (field(body, "password") !== "s3cret") return `password ${field(body, "password")}`;
    },
  },
  {
    name: "Hyperdrive connection string joins the other fields",
    request: ["http://test/hyperdrive/details"],
    status: 200,
    check: (body) => {
      const url = new URL(field(body, "connection_string"));
      const expected = {
        protocol: "postgresql:",
        username: field(body, "user"),
        password: field(body, "password"),
        hostname: field(body, "host"),
        port: field(body, "port"),
        pathname: "/app",
      };
      for (const [k, v] of Object.entries(expected))
        if (url[k] !== v) return `${k} is ${url[k]}, expected ${v}`;
    },
  },
  {
    name: "Hyperdrive accessors name the type and hide the value",
    request: ["http://test/hyperdrive/bad-fields"],
    status: 200,
    body: [
      "Workero.Decode: expected string, got null or undefined",
      "Workero.Decode: expected number, got string",
      "Workero.Decode: expected string, got number",
    ].join("\n"),
  },
  { name: "Hyperdrive.of_env rejects a variable", request: ["http://test/hyperdrive/shape?name=GREETING"], status: 200, body: shape("GREETING", "is a string, not a Hyperdrive binding") },
  { name: "Hyperdrive.of_env of a missing binding", request: ["http://test/hyperdrive/shape?name=NOPE"], status: 200, body: shape("NOPE", "not found") },
  { name: "Hyperdrive.of_env accepts the binding", request: ["http://test/hyperdrive/shape?name=HYPERDRIVE"], status: 200, body: "ok" },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
