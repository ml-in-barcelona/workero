import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export type NpmVersion = {
  dist: { tarball: string; integrity: string };
  dependencies?: Record<string, string>;
};

export const root = join(dirname(fileURLToPath(import.meta.url)), "..");

export const fail = (message: string): never => {
  console.error(message);
  process.exit(1);
};

export const fetchVersion = async (name: string, version: string): Promise<NpmVersion> => {
  const url = `https://registry.npmjs.org/${name.replace("/", "%2f")}/${version}`;
  const response = await fetch(url);
  if (!response.ok) return fail(`${url}: HTTP ${response.status}`);
  return (await response.json()) as NpmVersion;
};

export const sha512Hex = (integrity: string): string => {
  const [algorithm, digest] = integrity.split("-");
  if (algorithm !== "sha512" || digest === undefined) {
    return fail(`Expected a sha512 integrity, got ${integrity}`);
  }
  return Buffer.from(digest, "base64").toString("hex");
};

export const maintainerFields = `maintainer: ["David Sancho <dsnxmoreno@gmail.com>"]
authors: ["Cloudflare, Inc."]
bug-reports: "https://github.com/ml-in-barcelona/workero/issues"
dev-repo: "git+https://github.com/ml-in-barcelona/workero.git"
x-maintenance-intent: ["(latest)"]
`;
