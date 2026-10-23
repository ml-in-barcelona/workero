export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (pathname === "/log") {
      console.log("hello", 1, { a: 2 });
      console.warn("careful");
      return new Response("logged");
    }
    if (pathname === "/odd") {
      const loop = {};
      loop.self = loop;
      console.log(undefined, 10n, loop, () => 1);
      return new Response("odd");
    }
    if (pathname === "/throw") throw new Error("boom");
    return new Response("plain", { status: 201 });
  },
  async scheduled() {},
  async queue() {},
};
