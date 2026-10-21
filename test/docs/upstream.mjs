let scenario = "ok";
let hits = 0;

export default {
  async fetch(request) {
    if (new URL(request.url).pathname === "/control") {
      scenario = await request.text();
      hits = 0;
      return new Response("ready");
    }
    if (new URL(request.url).pathname === "/hits") return new Response(String(hits));
    hits++;
    if (scenario === "error") throw new Error("documented origin failure");
    if (scenario === "status")
      return new Response("unavailable", { status: 503, headers: { "x-origin": "unavailable" } });
    if (scenario === "cookie")
      return new Response("private", { headers: { "set-cookie": "session=one", "x-origin": "cookie" } });
    if (scenario === "policy")
      return new Response("policy", { headers: { "cache-control": "private", "x-origin": "policy" } });
    if (scenario === "vary")
      return new Response("vary", { headers: { vary: "*", "x-origin": "vary" } });
    return new Response("origin body", { headers: { "x-origin": "kept" } });
  },
};
