import { fail, fetchVersion, isVersion, platforms, sha512Hex, writeTemplate } from "./npm.ts";

const main = async (): Promise<void> => {
  const version = process.argv[2];
  if (!isVersion(version)) {
    return fail("Usage: node scripts/workerd-opam.ts <workerd version>, for example 1.20261019.1");
  }
  const sources = await Promise.all(
    platforms.map(async (p) => ({
      p,
      v: await fetchVersion(`@cloudflare/workerd-${p.npm}`, version),
    })),
  );
  writeTemplate(
    "workerd",
    `version: "${version}"
available: [ (os = "linux" | os = "macos") & (arch = "x86_64" | arch = "arm64") ]
depends: []
build: [
  ["tar" "-xzf"
${platforms
  .map((p) => `    "workerd-${p.npm}.tgz" {os = "${p.os}" & arch = "${p.arch}"}`)
  .join("\n")}
  ]
]
install: [
  ["install" "-m" "755" "package/bin/workerd" "%{bin}%/workerd"]
]
${sources
  .map(
    ({ p, v }) => `extra-source "workerd-${p.npm}.tgz" {
  src: "${v.dist.tarball}"
  checksum: "sha512=${sha512Hex(v.dist.integrity)}"
}`,
  )
  .join("\n")}
`,
  );
};

await main();
