import http from "./cases/http.mjs";
import stream from "./cases/stream.mjs";
import form from "./cases/form.mjs";
import ws from "./cases/ws.mjs";
import context from "./cases/context.mjs";
import globals from "./cases/globals.mjs";

export default {
  async test(_controller, env) {
    const failures = [];
    for (const suite of [http, stream, form, ws, context, globals]) await suite(env, failures);
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
