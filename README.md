# workero

Write Cloudflare Workers in OCaml. workero compiles OCaml to WebAssembly with
wasm_of_ocaml and packages the result for Wrangler. Handlers run in direct
style: `Workero.fetch` waits for a response while other requests can run.

## Start a Worker

You need an active opam switch with OCaml 5.4 or later, Git, and Node.js 22 or
later for Wrangler. wasm_of_ocaml needs `wasm-opt` from binaryen 119 or later on
`PATH`: run `npm install -g binaryen` or build it from
[source](https://github.com/WebAssembly/binaryen). The `workero` package is not
yet available from the opam package index. Run these commands from a directory
outside any Dune project:

```sh
eval "$(opam env)"
git clone https://github.com/ml-in-barcelona/workero.git workero-source
opam pin add workero ./workero-source -y
opam install wrangler -y
cp -R workero-source/template my-worker
cd my-worker
opam exec -- wrangler dev
```

The source pin installs the library and CLI. `opam install wrangler` installs
Wrangler and workerd. The CLI uses workerd to check initialization and discover
Durable Object, entrypoint, and Workflow classes. Wrangler prints
the local URL, usually `http://127.0.0.1:8787`. In another terminal, run:

```sh
curl http://127.0.0.1:8787/
```

Expected response: `Hello from OCaml on Cloudflare Workers`.

The handler in `my-worker/src/main.ml` reads a request and returns a response:

```ocaml
let handler req _env _ctx =
  match Workero.URL.path (Workero.Request.url req) with
  | "/" -> Workero.Response.text "Hello from OCaml on Cloudflare Workers\n"
  | _ -> Workero.Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```

Follow [Getting started](https://ml-in-barcelona.github.io/workero/workero/getting_started.html)
to edit the template and run it locally. The [Runtime APIs](https://ml-in-barcelona.github.io/workero/workero/runtime_apis.html)
and [Bindings](https://ml-in-barcelona.github.io/workero/workero/bindings.html)
guides cover requests, JSON, routing, HTML rewriting, scheduled handlers,
tail Workers, sockets, email, entrypoints and RPC, Workflows, Queues, Hyperdrive, Durable Objects, SQL,
hibernating WebSockets, and Containers.
See the [CLI guide](https://ml-in-barcelona.github.io/workero/workero/cli.html)
for packaging and [CONTRIBUTING.md](CONTRIBUTING.md) for repository work.

## Demos

- [Basic Worker](examples/basic/) ([demo](https://workero-example-basic.davesnx.workers.dev)): runtime and isolate information.
- [Runtime limits](examples/limits/) ([demo](https://workero-example-limits.davesnx.workers.dev)): CPU and memory experiments.
- [OCaml features](examples/features/) ([demo](https://workero-example-features.davesnx.workers.dev)): standard library and runtime features.
- [Effects](examples/hello/) ([demo](https://workero-example-hello.davesnx.workers.dev)): effect handlers and Promise waits.
- [Promises](examples/promise/) ([demo](https://workero-example-promise.davesnx.workers.dev)): sequential and concurrent waits.
- [React rendering](examples/react/) ([demo](https://workero-example-react.davesnx.workers.dev)): server-side rendering in OCaml.
