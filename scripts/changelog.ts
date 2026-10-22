import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fail, isVersion, root } from "./npm.ts";

const unreleased = "## Unreleased";

export const addSection = (text: string, version: string, fallback: string): string => {
  const lines = text.split("\n");
  if (lines.includes(`## ${version}`)) return text;
  const start = lines.indexOf(unreleased);
  if (start === -1) return fail(`The changelog has no "${unreleased}" section`);
  const next = lines.findIndex((line, i) => i > start && line.startsWith("## "));
  const end = next === -1 ? lines.length : next;
  const notes = lines.slice(start + 1, end).join("\n").trim();
  const section = [`## ${version}`, "", notes === "" ? fallback : notes, ""];
  return [...lines.slice(0, start + 1), "", ...section, ...lines.slice(end)].join("\n");
};

const main = (): void => {
  const [name, version, fallback] = process.argv.slice(2);
  if ((name !== "workerd" && name !== "wrangler") || !isVersion(version) || fallback === undefined) {
    return fail('Usage: node scripts/changelog.ts <workerd|wrangler> <version> "<default note>"');
  }
  const file = join(root, `CHANGES-${name}.md`);
  writeFileSync(file, addSection(readFileSync(file, "utf8"), version, fallback));
};

if (process.argv[1] === import.meta.filename) main();
