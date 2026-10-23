const hex = (bytes) => [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
const fromBase64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const log = [];
const accepted = { metadata: { metrics: { backlogCount: 0, backlogBytes: 0, oldestMessageTimestamp: 0 } } };

const entry = (format, bytes, delay) => ({
  format,
  delay,
  body: format === "text" || format === "json" ? new TextDecoder().decode(bytes) : hex(bytes),
});

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/log") {
      if (request.method === "DELETE") log.length = 0;
      return Response.json(log);
    }
    const bytes = new Uint8Array(await request.arrayBuffer());
    if (url.pathname === "/message") {
      const text = new TextDecoder().decode(bytes);
      if (text === "reject") return new Response("rejected by the sink", { status: 500 });
      log.push({
        path: "/message",
        ...entry(request.headers.get("x-msg-fmt"), bytes, request.headers.get("x-msg-delay-secs")),
      });
    } else if (url.pathname === "/batch") {
      const { messages } = JSON.parse(new TextDecoder().decode(bytes));
      log.push({
        path: "/batch",
        delay: request.headers.get("x-msg-delay-secs"),
        messages: messages.map((m) =>
          entry(m.contentType, fromBase64(m.body), m.delaySecs === undefined ? null : String(m.delaySecs)),
        ),
      });
    }
    return Response.json(accepted);
  },
};
