let slowHits = 0;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (pathname === "/slow") {
      slowHits++;
      await sleep(500);
      return new Response("slow done");
    }
    if (pathname === "/slow-hits") return new Response(String(slowHits));
    if (pathname === "/slow-body") {
      const encoder = new TextEncoder();
      return new Response(
        new ReadableStream({
          async start(controller) {
            controller.enqueue(encoder.encode("first;"));
            await sleep(500);
            controller.enqueue(encoder.encode("second"));
            controller.close();
          },
        }),
      );
    }
    if (pathname === "/echo") {
      const { headers } = request;
      return new Response(
        `${request.method}|${headers.get("x-a")},${headers.get("x-b")}|${await request.text()}`,
        { status: 203, headers: { "x-upstream": "yes" } },
      );
    }
    if (pathname === "/raw") return new Response(await request.arrayBuffer());
    if (pathname === "/bytes")
      return new Response(new Uint8Array([0, 255, 128, 10]), {
        headers: { "x-one": "1", "x-two": "2" },
      });
    if (pathname === "/cookies") {
      const headers = new Headers();
      headers.append("set-cookie", "a=1; Path=/");
      headers.append("set-cookie", "b=2; Expires=Wed, 21 Oct 2026 07:28:00 GMT");
      return new Response("ok", { headers });
    }
    throw new Error("upstream down");
  },
  async connect(socket) {
    const reader = socket.readable.getReader();
    const writer = socket.writable.getWriter();
    const bye = new TextEncoder().encode("bye");
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      if (value.length === bye.length && value.every((b, i) => b === bye[i])) await writer.close();
      else await writer.write(value);
    }
    await writer.close().catch(() => {});
  },
};
