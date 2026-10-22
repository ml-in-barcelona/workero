import { execFileSync } from "node:child_process";
import { fail, fetchVersion, isVersion, latestVersion } from "./npm.ts";

export type Release = { name: "workerd" | "wrangler"; version: string };

export const targets = (wrangler: string, pinned: string): Release[] => [
  { name: "workerd", version: pinned },
  { name: "wrangler", version: wrangler },
];

export const tagOf = (release: Release): string => `${release.name}-${release.version}`;

const main = async (): Promise<void> => {
  const wrangler = (await latestVersion("wrangler")).version;
  const pinned = (await fetchVersion("wrangler", wrangler)).dependencies?.["workerd"];
  if (!isVersion(pinned)) return fail(`wrangler ${wrangler} pins workerd ${pinned}, not an exact version`);
  const tags = new Set(execFileSync("git", ["tag", "--list"], { encoding: "utf8" }).split("\n"));
  const wanted = process.argv[2] === "--tagged";
  for (const release of targets(wrangler, pinned)) {
    if (tags.has(tagOf(release)) === wanted) console.log(`${release.name} ${release.version}`);
  }
};

if (process.argv[1] === import.meta.filename) await main();
