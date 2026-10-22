import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fail } from "./npm.ts";

const esbuildPlatforms = ["linux-x64", "linux-arm64", "darwin-x64", "darwin-arm64"];

const run = (cwd: string, ...command: string[]): void => {
  const [program, ...args] = command;
  if (program === undefined) return;
  execFileSync(program, args, { cwd, stdio: "inherit" });
};

const main = (): void => {
  const [version, outDir] = process.argv.slice(2);
  if (version === undefined || outDir === undefined || !/^\d+\.\d+\.\d+$/.test(version)) {
    return fail("Usage: node scripts/wrangler-bundle.ts <wrangler version> <output directory>");
  }
  const top = `wrangler-${version}`;
  const work = join(mkdtempSync(join(tmpdir(), "wrangler-bundle-")), top);
  mkdirSync(work);
  writeFileSync(join(work, "package.json"), '{"name":"wrangler-bundle","private":true}\n');
  run(work, "npm", "install", "--omit=optional", "--ignore-scripts", "--no-audit", "--no-fund", "--save-exact", `wrangler@${version}`);

  const esbuild = (
    JSON.parse(readFileSync(join(work, "node_modules", "esbuild", "package.json"), "utf8")) as { version: string }
  ).version;
  for (const platform of esbuildPlatforms) {
    const target = join(work, "node_modules", "@esbuild", platform);
    mkdirSync(target, { recursive: true });
    run(work, "npm", "pack", `@esbuild/${platform}@${esbuild}`, "--pack-destination", work);
    run(work, "tar", "-xzf", `esbuild-${platform}-${esbuild}.tgz`, "-C", target, "--strip-components=1");
    run(work, "rm", `esbuild-${platform}-${esbuild}.tgz`);
  }

  mkdirSync(outDir, { recursive: true });
  const archive = join(resolve(outDir), `${top}.tgz`);
  run(join(work, ".."), "tar", "-czf", archive, top);
  console.log(archive);
};

main();
