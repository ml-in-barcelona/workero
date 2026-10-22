import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { fail, fetchVersion, maintainerFields, root } from "./npm.ts";

type Platform = { npm: string; os: "linux" | "macos"; arch: "x86_64" | "arm64" };

const platforms: Platform[] = [
  { npm: "linux-64", os: "linux", arch: "x86_64" },
  { npm: "linux-arm64", os: "linux", arch: "arm64" },
  { npm: "darwin-64", os: "macos", arch: "x86_64" },
  { npm: "darwin-arm64", os: "macos", arch: "arm64" },
];

const nodeCheck =
  'if (parseInt(process.versions.node) < 22) { console.error(\\"wrangler needs Node.js 22 or later\\"); process.exit(1); }';

const linkWorkerd = (p: Platform): string =>
  `  ["sh" "-c" "mkdir -p \\"$0/bin\\" && ln -sf \\"$1\\" \\"$0/bin/workerd\\"" "%{lib}%/wrangler/node_modules/@cloudflare/workerd-${p.npm}" "%{bin}%/workerd"] {os = "${p.os}" & arch = "${p.arch}"}`;

const wranglerFile = (version: string, workerd: string): string => `opam-version: "2.0"
version: "${version}"
synopsis: "Wrangler, the Cloudflare Workers command line tool"
description:
  "Wrangler builds, runs and deploys Cloudflare Workers. This package installs a bundle of Wrangler and its JavaScript dependencies. It uses the workerd package as its runtime. It needs Node.js 22 or later."
license: "MIT OR Apache-2.0"
homepage: "https://github.com/cloudflare/workers-sdk/tree/main/packages/wrangler"
${maintainerFields}available: [ (os = "linux" | os = "macos") & (arch = "x86_64" | arch = "arm64") ]
depends: [
  "conf-npm"
  "workerd" {= "${workerd}"}
]
build: [
  ["node" "-e" "${nodeCheck}"]
]
install: [
  ["mkdir" "-p" "%{lib}%/wrangler"]
  ["cp" "-R" "node_modules" "%{lib}%/wrangler/"]
${platforms.map(linkWorkerd).join("\n")}
  ["ln" "-sf" "../lib/wrangler/node_modules/wrangler/bin/wrangler.js" "%{bin}%/wrangler"]
]
`;

const main = async (): Promise<void> => {
  const version = process.argv[2];
  if (version === undefined || !/^\d+\.\d+\.\d+$/.test(version)) {
    return fail("Usage: node scripts/wrangler-opam.ts <wrangler version>, for example 4.151.3");
  }
  const workerd = (await fetchVersion("wrangler", version)).dependencies?.["workerd"];
  if (workerd === undefined) return fail(`wrangler ${version} does not depend on workerd`);
  writeFileSync(join(root, "wrangler", "wrangler.opam"), wranglerFile(version, workerd));
};

await main();
