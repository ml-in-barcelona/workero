import { readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const out = process.argv[2];
const names = ["README", "TEMPLATE", "REQUESTS", "STREAMS", "FORMS", "JSON", "CACHE"];
const modules = (dir) => {
  const visit = (path, relative = "") => readdirSync(path, { withFileTypes: true })
    .flatMap((entry) => entry.isDirectory()
      ? visit(join(path, entry.name), `${relative}${entry.name}/`)
      : [`${relative}${entry.name}`]);
  const files = visit(join(out, dir)).filter((file) => /\.(js|wasm)$/.test(file)).sort();
  if (!files.includes("index.js") || !files.some((file) => file.endsWith(".wasm")))
    throw new Error(`Incomplete packaged worker: ${dir}`);
  return files.map((file) =>
    `        (name = "${file}", ${file.endsWith(".wasm") ? "wasm" : "esModule"} = embed "${dir}/${file}"),`)
    .join("\n");
};
const services = names.map((name) => `
    (name = "${name}", worker = (
      compatibilityDate = "2026-10-01",
      modules = [
${modules(name)}
      ],
      bindings = [(name = "GREETING", text = "hello from vars")],
      globalOutbound = "origin",
      cacheApiOutbound = "cache-store",
    )),`).join("");
writeFileSync(join(out, "config.capnp"), `using Workerd = import "/workerd/workerd.capnp";
const config :Workerd.Config = (
  services = [${services}
    (name = "origin", worker = (
      compatibilityDate = "2026-10-01",
      modules = [(name = "upstream.mjs", esModule = embed "upstream.mjs")],
    )),
    (name = "cache-store", worker = (
      compatibilityDate = "2026-10-01",
      modules = [(name = "cache.mjs", esModule = embed "cache.mjs")],
    )),
    (name = "tests", worker = (
      compatibilityDate = "2026-10-01",
      modules = [(name = "tests.mjs", esModule = embed "tests.mjs")],
      bindings = [
${names.map((name) => `        (name = "${name}", service = "${name}"),`).join("\n")}
        (name = "ORIGIN", service = "origin"),
      ],
    )),
  ],
);
`);
