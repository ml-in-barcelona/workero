import handlers from "./index.js";
import { EmailMessage } from "cloudflare:email";

const mockMessage = (spec, calls) => ({
  from: spec.from,
  to: spec.to,
  headers: new Headers(spec.headers),
  rawSize: spec.chunks.reduce((n, chunk) => n + chunk.length, 0),
  raw: new ReadableStream({
    start(controller) {
      for (const chunk of spec.chunks) controller.enqueue(new Uint8Array(chunk));
      controller.close();
    },
  }),
  setReject(reason) {
    calls.push({ op: "setReject", reason });
  },
  async forward(recipient, headers) {
    if (spec.forwardError) throw new Error(spec.forwardError);
    calls.push({ op: "forward", recipient, headers: headers ? [...headers] : null });
  },
  async reply(message) {
    calls.push({
      op: "reply",
      isEmailMessage: message instanceof EmailMessage,
      from: message.from,
      to: message.to,
      raw: message.raw,
    });
  },
});

export default {
  async fetch(request, env, ctx) {
    const spec = await request.json();
    const calls = [];
    let error = null;
    try {
      await handlers.email(mockMessage(spec, calls), env, ctx);
    } catch (e) {
      error = String(e);
    }
    return Response.json({ calls, error, exported: Object.keys(handlers) });
  },
};
