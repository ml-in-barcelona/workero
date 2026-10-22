import { fail, fetchVersion, isVersion, platforms, writeTemplate } from "./npm.ts";

const nodeCheck =
  'if (parseInt(process.versions.node) < 22) { console.error(\\"wrangler needs Node.js 22 or later\\"); process.exit(1); }';

const linkWorkerd = (p: (typeof platforms)[number]): string =>
  `  ["sh" "-c" "mkdir -p \\"$0/bin\\" && ln -sf \\"$1\\" \\"$0/bin/workerd\\"" "%{lib}%/wrangler/node_modules/@cloudflare/workerd-${p.npm}" "%{bin}%/workerd"] {os = "${p.os}" & arch = "${p.arch}"}`;

const main = async (): Promise<void> => {
  const version = process.argv[2];
  if (!isVersion(version)) {
    return fail("Usage: node scripts/wrangler-opam.ts <wrangler version>, for example 4.151.3");
  }
  const workerd = (await fetchVersion("wrangler", version)).dependencies?.["workerd"];
  if (!isVersion(workerd)) return fail(`wrangler ${version} pins workerd ${workerd}, not an exact version`);
  writeTemplate(
    "wrangler",
    `version: "${version}"
available: [ (os = "linux" | os = "macos") & (arch = "x86_64" | arch = "arm64") ]
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
`,
  );
};

await main();
