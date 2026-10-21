
# workero

Write Cloudflare Workers in OCaml (via wasm\_of\_ocaml).


## Library

The entry point is the module [`Workero`](./Workero.md).

[`Workero`](./Workero.md) Write Cloudflare Workers in OCaml (via wasm\_of\_ocaml)

## Guides

The pages follow the order of a Worker project.

- [Getting started](./getting_started.md): prerequisites, create a project, develop locally, deploy.
- [Handlers](./handlers.md): `Workero.serve`, `Workero.scheduled`, and the arguments of a handler.
- [Requests and responses](./requests.md): requests, responses, URLs, JSON and `Workero.fetch`.
- [Streams](./streams.md): read a body in chunks, send a body in steps.
- [Forms](./forms.md): forms and file uploads.
- [WebSockets](./websockets.md): accept a connection and read its messages.
- [Variables and secrets](./env.md): `Env.var`, `Env.secret`, `Env.json` and Secrets Store.
- [Waiting for JavaScript](./async.md): direct style, `Promise.await` and background work.
- [Bindings](./bindings.md): [KV](./kv.md), [Cache](./cache.md), [R2](./r2.md) and [D1](./d1.md), [Fetcher](./fetcher.md).
- [Durable Objects](./durable_objects.md): classes, stubs, storage and alarms.
- [Logging](./logging.md): output and `Workero.Console`.
- [JavaScript globals](./globals.md): timers, `Date`, `crypto`.
- [Testing and limits](./testing.md).
- [JavaScript interop](./interop.md).
- [How it works](./how_it_works.md): wasm\_of\_ocaml, JSPI, `workero build` and binary size.
- [Supported libraries](./libraries.md).
- [Support and known issues](./known_issues.md).
- [CLI](./cli.md): the `workero` command.
- [Template](./template.md): the starter project.