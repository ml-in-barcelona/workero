import http from "./cases/http.mjs";
import stream from "./cases/stream.mjs";
import form from "./cases/form.mjs";
import ws from "./cases/ws.mjs";
import context from "./cases/context.mjs";
import globals from "./cases/globals.mjs";
import envSuite from "./cases/env.mjs";
import fetcher from "./cases/fetcher.mjs";
import router from "./cases/router.mjs";
import rateLimiter from "./cases/rate_limiter.mjs";
import ai from "./cases/ai.mjs";
import analytics from "./cases/analytics.mjs";
import durableObject from "./cases/do.mjs";
import socket from "./cases/socket.mjs";

export default {
  async test(_controller, env) {
    const failures = [];
    for (const suite of [http, stream, form, ws, context, globals, envSuite, fetcher, router, rateLimiter, ai, analytics, socket, durableObject]) await suite(env, failures);
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
