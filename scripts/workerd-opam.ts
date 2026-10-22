import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { fail, fetchVersion, maintainerFields, root, sha512Hex, type NpmVersion } from "./npm.ts";

type Platform = {
  npm: string;
  os: "linux" | "macos";
  arch: "x86_64" | "arm64";
  label: string;
};

const platforms: Platform[] = [
  { npm: "linux-64", os: "linux", arch: "x86_64", label: "Linux x86_64" },
  { npm: "linux-arm64", os: "linux", arch: "arm64", label: "Linux arm64" },
  { npm: "darwin-64", os: "macos", arch: "x86_64", label: "macOS x86_64" },
  { npm: "darwin-arm64", os: "macos", arch: "arm64", label: "macOS arm64" },
];

const platformFile = (p: Platform, version: string, v: NpmVersion): string => `opam-version: "2.0"
version: "${version}"
synopsis: "The workerd binary for ${p.label}"
description:
  "The prebuilt workerd binary from Cloudflare for ${p.label}. Install the workerd package instead; it selects this one."
license: "Apache-2.0"
homepage: "https://github.com/cloudflare/workerd"
${maintainerFields}available: os = "${p.os}" & arch = "${p.arch}"
install: [
  ["install" "-m" "755" "bin/workerd" "%{bin}%/workerd"]
]
url {
  src: "${v.dist.tarball}"
  checksum: "sha512=${sha512Hex(v.dist.integrity)}"
}
`;

const metaFile = (version: string): string => `opam-version: "2.0"
version: "${version}"
synopsis: "The workerd runtime for Cloudflare Workers"
description:
  "Installs the prebuilt workerd binary from Cloudflare for your platform: Linux or macOS, x86_64 or arm64. Linux needs glibc 2.35 or later."
license: "Apache-2.0"
homepage: "https://github.com/cloudflare/workerd"
${maintainerFields}available: [ os = "linux" | os = "macos" ]
depends: [
${platforms
  .map(
    (p) =>
      `  "workerd-${p.npm}" {= version & os = "${p.os}" & arch = "${p.arch}"}`,
  )
  .join("\n")}
]
`;

const main = async (): Promise<void> => {
  const version = process.argv[2];
  if (version === undefined || !/^\d+\.\d+\.\d+$/.test(version)) {
    return fail("Usage: node scripts/workerd-opam.ts <workerd version>, for example 1.20261019.1");
  }
  for (const p of platforms) {
    const v = await fetchVersion(`@cloudflare/workerd-${p.npm}`, version);
    writeFileSync(join(root, "workerd", "platform", `workerd-${p.npm}.opam`), platformFile(p, version, v));
  }
  writeFileSync(join(root, "workerd", "workerd.opam"), metaFile(version));
};

await main();
