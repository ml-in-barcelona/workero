const hex = (bytes) => [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");

export default {
  async fetch(request) {
    const url = new URL(request.url);
    switch (url.pathname) {
      case "/hex":
        return new Response(hex(new Uint8Array(await request.arrayBuffer())));
      case "/teapot":
        return new Response("short and stout", { status: 418, headers: { "x-backend": "teapot" } });
      case "/boom":
        throw new Error("backend boom");
    }
    return new Response(
      `${request.method}|${url.pathname}${url.search}|${request.headers.get("x-a")}|${await request.text()}`,
      { headers: { "x-backend": "echo" } },
    );
  },
};
