import * as handlers from "./index.js";

const mockMessage = (spec, calls) => ({
  from: spec.from,
  to: spec.to,
  headers: new Headers(),
  rawSize: 0,
  raw: new ReadableStream({ start: (controller) => controller.close() }),
  setReject(reason) {
    calls.push({ op: "setReject", reason });
  },
});

export default {
  async fetch(request, env, ctx) {
    const spec = await request.json();
    const calls = [];
    let error = null;
    try {
      const instance = new handlers[spec.entrypoint](ctx, env);
      if (typeof instance.email !== "function") throw new Error("the entrypoint has no email handler");
      await instance.email(mockMessage(spec, calls));
    } catch (e) {
      error = String(e);
    }
    return Response.json({ calls, error });
  },
};
