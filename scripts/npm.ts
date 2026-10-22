import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export type NpmVersion = {
  version: string;
  dist: { tarball: string; integrity: string };
  dependencies?: Record<string, string>;
};

export type Platform = {
  npm: string;
  os: "linux" | "macos";
  arch: "x86_64" | "arm64";
  label: string;
};

export const platforms: Platform[] = [
  { npm: "linux-64", os: "linux", arch: "x86_64", label: "Linux x86_64" },
  { npm: "linux-arm64", os: "linux", arch: "arm64", label: "Linux arm64" },
  { npm: "darwin-64", os: "macos", arch: "x86_64", label: "macOS x86_64" },
  { npm: "darwin-arm64", os: "macos", arch: "arm64", label: "macOS arm64" },
];

export const root = join(dirname(fileURLToPath(import.meta.url)), "..");

export const fail = (message: string): never => {
  console.error(message);
  process.exit(1);
};

export const isVersion = (value: string | undefined): value is string =>
  value !== undefined && /^\d+\.\d+\.\d+$/.test(value);

export const fetchVersion = async (name: string, version: string): Promise<NpmVersion> => {
  const url = `https://registry.npmjs.org/${name.replace("/", "%2f")}/${version}`;
  const response = await fetch(url);
  if (!response.ok) return fail(`${url}: HTTP ${response.status}`);
  return (await response.json()) as NpmVersion;
};

export const latestVersion = async (name: string): Promise<NpmVersion> => fetchVersion(name, "latest");


export const sha512Hex = (integrity: string): string => {
  const [algorithm, digest] = integrity.split("-");
  if (algorithm !== "sha512" || digest === undefined) {
    return fail(`Expected a sha512 integrity, got ${integrity}`);
  }
  return Buffer.from(digest, "base64").toString("hex");
};

export const writeTemplate = (name: string, content: string): void => {
  writeFileSync(join(root, `${name}.opam.template`), content);
};
