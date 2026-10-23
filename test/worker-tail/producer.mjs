import { DurableObject, WorkerEntrypoint } from "cloudflare:workers";

export class Svc extends WorkerEntrypoint {
  ping() {
    return "pong";
  }
}

export class Counter extends DurableObject {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (pathname === "/alarm") {
      await this.ctx.storage.setAlarm(Date.now() + 10);
      return new Response("set");
    }
    const pair = new WebSocketPair();
    this.ctx.acceptWebSocket(pair[1]);
    return new Response(null, { status: 101, webSocket: pair[0] });
  }
  async alarm() {}
  async webSocketMessage(ws) {
    ws.send("echo");
  }
  async webSocketClose(ws, code) {
    ws.close(code);
  }
}

export default {
  async fetch(request, env) {
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
    if (pathname === "/alarm" || pathname === "/ws") return env.COUNTER.get(env.COUNTER.idFromName("c")).fetch(request);
    return new Response("plain", { status: 201 });
  },
  async scheduled() {},
  async queue() {},
};
