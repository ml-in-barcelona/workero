import { DurableObject, WorkerEntrypoint } from "cloudflare:workers";

const kind = (v) => {
  if (v === null) return "null";
  if (typeof v !== "object") return typeof v;
  if (v instanceof Uint8Array) return "Uint8Array";
  if (Array.isArray(v)) return "Array";
  if (v instanceof Date) return "Date";
  if (v instanceof Map) return "Map";
  if (v instanceof Set) return "Set";
  if (v instanceof ReadableStream) return "ReadableStream";
  if (Object.prototype.toString.call(v) === "[object Fetcher]") return "Fetcher";
  return "Object";
};

const methods = {
  same: (v) => v,
  kind: (v) => kind(v),
  call_fn: async (f, x) => await f(x),
  make_fn: () => (x) => x + 1,
  stream_text: async (s) => await new Response(s).text(),
  make_stream: () =>
    new ReadableStream({
      start(controller) {
        controller.enqueue(new TextEncoder().encode("abc"));
        controller.enqueue(new TextEncoder().encode("def"));
        controller.close();
      },
    }),
  stub_text: async (s) => await (await s.fetch("http://x/p")).text(),
  give_stub() {
    return this.env.BACKEND;
  },
};

export class Js extends WorkerEntrypoint {
  nothing() {}
  object() {
    return { a: [1, 2], b: null };
  }
  big() {
    return 10n;
  }
  typed() {
    return new Float64Array([1]);
  }
  async delayed(x) {
    await new Promise((resolve) => setTimeout(resolve, 10));
    return x;
  }
}

export class JsObject extends DurableObject {}

Object.assign(Js.prototype, methods);
Object.assign(JsObject.prototype, methods);
