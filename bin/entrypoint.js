import { WorkerEntrypoint } from "cloudflare:workers";

export class WorkeroEntrypoint extends WorkerEntrypoint {
  constructor(ctx, env, name) {
    super(ctx, env);
    const factory = globalThis.__workero?.entrypoints?.[name];
    if (typeof factory !== "function")
      throw new Error(
        `workero: class ${name} is exported but the OCaml program did not call Workero.Entrypoint.register "${name}"`,
      );
    const handlers = factory(env, ctx);
    if (typeof handlers.fetch === "function") this.fetch = (...args) => handlers.fetch(...args);
    for (const event of ["scheduled", "queue", "email"])
      if (typeof handlers[event] === "function") this[event] = (...args) => handlers[event](...args);
    this[Symbol.for("workero.rpc")] = (method, args) => {
      if (typeof handlers.rpc !== "function")
        throw new Error(`workero: class ${name} declares the RPC method ${method} but its handlers have no ~rpc`);
      return handlers.rpc(method, args);
    };
  }
}
