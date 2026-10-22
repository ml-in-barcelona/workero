import { fail, fetchVersion, isVersion, platforms, sha512Hex, writeTemplate } from "./npm.ts";

const main = async (): Promise<void> => {
  const version = process.argv[2];
  if (!isVersion(version)) {
    return fail("Usage: node scripts/workerd-opam.ts <workerd version>, for example 1.20261019.1");
  }
  for (const p of platforms) {
    const v = await fetchVersion(`@cloudflare/workerd-${p.npm}`, version);
    writeTemplate(
      `workerd-${p.npm}`,
      `version: "${version}"
available: os = "${p.os}" & arch = "${p.arch}"
depends: []
build: []
install: [
  ["install" "-m" "755" "bin/workerd" "%{bin}%/workerd"]
]
url {
  src: "${v.dist.tarball}"
  checksum: "sha512=${sha512Hex(v.dist.integrity)}"
}
`,
    );
  }
  writeTemplate(
    "workerd",
    `version: "${version}"
available: [ os = "linux" | os = "macos" ]
depends: [
${platforms
  .map((p) => `  "workerd-${p.npm}" {= version & os = "${p.os}" & arch = "${p.arch}"}`)
  .join("\n")}
]
build: []
`,
  );
};

await main();
