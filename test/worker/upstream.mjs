export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
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
    throw new Error("upstream down");
  },
};
