
# workero

Write Cloudflare Workers in OCaml. workero compiles your program to WebAssembly with wasm\_of\_ocaml and provides OCaml interfaces to runtime APIs and Cloudflare bindings.

Handlers run in direct style. Calls such as `Workero.fetch` wait for their result while the runtime handles other requests.


## Get started

- [Get started](./getting_started.md): create a Worker, run it locally, and deploy it.
- [Starter project](./template.md): files, build configuration, and example routes.

## Runtime APIs

Use [runtime APIs](./runtime_apis.md) to handle HTTP requests, make outgoing requests, stream data, and run background work.


## Bindings

[Bindings](./bindings.md) expose configuration and Cloudflare resources through your handler's `env` argument.

- [Variables and secrets](./env.md).
- [Workers KV](./kv.md).
- [R2](./r2.md).
- [D1](./d1.md).

## Development and deployment

- [Build and package](./cli.md): the `workero` command.
- [Test a Worker](./testing.md).
- [OCaml library compatibility](./libraries.md).
- [Runtime limits](./limits.md).
- [Troubleshooting and support](./known_issues.md).

## Advanced

- [How Workero works](./how_it_works.md): compilation, effects, and the JavaScript entry point.
- [JavaScript interop](./interop.md): call APIs that Workero does not wrap.

## OCaml API reference

The [`Workero`](./Workero.md) module reference lists types, functions, defaults, and exceptions.

[`Workero`](./Workero.md) Write Cloudflare Workers in OCaml (via wasm\_of\_ocaml)