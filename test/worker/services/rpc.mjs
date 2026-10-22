import { WorkerEntrypoint } from "cloudflare:workers";

export class Js extends WorkerEntrypoint {
  nothing() {}
  object() {
    return { a: [1, 2], b: null };
  }
  big() {
    return 10n;
  }
  async delayed(x) {
    await new Promise((resolve) => setTimeout(resolve, 10));
    return x;
  }
}
