import { execFileSync } from "node:child_process";
import { fail, fetchVersion, isVersion, latestVersion } from "./npm.ts";

const hasTag = (tag: string): boolean =>
  execFileSync("git", ["tag", "--list", tag], { encoding: "utf8" }).trim() === tag;

const main = async (): Promise<void> => {
  const [name, mode] = process.argv.slice(2);
  if ((name !== "workerd" && name !== "wrangler") || (mode !== undefined && mode !== "--tagged")) {
    return fail("Usage: node scripts/upstream.ts <workerd|wrangler> [--tagged]");
  }
  const wrangler = (await latestVersion("wrangler")).version;
  const pinned = (await fetchVersion("wrangler", wrangler)).dependencies?.["workerd"];
  if (!isVersion(pinned)) return fail(`wrangler ${wrangler} pins workerd ${pinned}, not an exact version`);
  const version = name === "workerd" ? pinned : wrangler;
  const tagged = hasTag(`${name}-${version}`);
  if (mode === "--tagged") {
    if (tagged) console.log(version);
    return;
  }
  if (tagged) return;
  if (name === "wrangler" && !hasTag(`workerd-${pinned}`)) {
    console.error(`Skip wrangler ${version}: the tag workerd-${pinned} does not exist yet.`);
    return;
  }
  console.log(version);
};

await main();
