import { DurableObject } from "cloudflare:workers";

export class WorkeroDurableObject extends DurableObject {
  constructor(ctx, env, name) {
    super(ctx, env);
    const factory = globalThis.__workero?.durable_objects?.[name];
    if (typeof factory !== "function")
      throw new Error(
        `workero: class ${name} is exported but the OCaml program did not call Workero.Durable_object.register "${name}"`,
      );
    const handlers = factory(ctx, env);
    for (const method of ["fetch", "alarm", "webSocketMessage", "webSocketClose", "webSocketError"]) {
      if (typeof handlers[method] === "function")
        this[method] = (...args) => handlers[method](...args);
    }
    this[Symbol.for("workero.rpc")] = (method, args) => {
      if (typeof handlers.rpc !== "function")
        throw new Error(`workero: class ${name} declares the RPC method ${method} but its handlers have no ~rpc`);
      return handlers.rpc(method, args);
    };
    if (typeof handlers.init === "function")
      ctx.blockConcurrencyWhile(() => handlers.init());
  }
}
