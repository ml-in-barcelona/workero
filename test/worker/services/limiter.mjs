import { WorkerEntrypoint } from "cloudflare:workers";

const allowed = 2;
const counts = new Map();

export class Limiter extends WorkerEntrypoint {
  async limit(options) {
    if (options.key === "throw") throw new Error("limiter unavailable");
    const count = (counts.get(options.key) ?? 0) + 1;
    counts.set(options.key, count);
    return { success: count <= allowed };
  }
}
