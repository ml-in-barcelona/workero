# workero

Write Cloudflare Workers in OCaml. workero compiles an OCaml 5 program to
WebAssembly with wasm_of_ocaml and packages it for Wrangler.

Handlers run in direct style. Calls such as `Workero.fetch` wait for their
result while the runtime handles other requests.

## Start a worker

You need [opam](https://opam.ocaml.org/doc/Install.html) with an active OCaml
5.4 or later switch, [Git](https://git-scm.com/), and Node.js 22 or later with
npm. Run these commands from a directory outside any Dune project:

```sh
eval "$(opam env)"
git clone https://github.com/ml-in-barcelona/workero.git workero-source
opam pin add workero ./workero-source -y
cp -R workero-source/template my-worker
cd my-worker
npm install
npx wrangler dev
```

The source pin installs the library and `workero` CLI. The package is not yet
available from the opam package index. `npm install` provides Wrangler and
binaryen's `wasm-opt`. Wrangler builds the worker and prints its local URL,
usually `http://127.0.0.1:8787`. In another terminal, run:

```sh
curl http://127.0.0.1:8787/
```

Expected response: `Hello from OCaml on Cloudflare Workers`.

The handler in `my-worker/src/main.ml` can respond to requests directly:

```ocaml
let handler req _env _ctx =
  match Workero.URL.path (Workero.Request.url req) with
  | "/" -> Workero.Response.text "Hello from OCaml on Cloudflare Workers\n"
  | _ -> Workero.Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```

Read the [getting started guide](https://ml-in-barcelona.github.io/workero/workero/getting_started.html)
to edit and deploy the worker. See the [template guide](https://ml-in-barcelona.github.io/workero/workero/template.html),
[runtime APIs](https://ml-in-barcelona.github.io/workero/workero/runtime_apis.html),
[bindings](https://ml-in-barcelona.github.io/workero/workero/bindings.html),
[CLI guide](https://ml-in-barcelona.github.io/workero/workero/cli.html), and
[contribution guide](CONTRIBUTING.md) for more detail.

## Examples

- [Basic Worker](examples/basic/) ([demo](https://workero-example-basic.davesnx.workers.dev)): runtime and isolate information.
- [Runtime limits](examples/limits/) ([demo](https://workero-example-limits.davesnx.workers.dev)): CPU and memory experiments.
- [OCaml features](examples/features/) ([demo](https://workero-example-features.davesnx.workers.dev)): standard library and runtime features.
- [Effects](examples/hello/) ([demo](https://workero-example-hello.davesnx.workers.dev)): effect handlers and Promise waits.
- [Promises](examples/promise/) ([demo](https://workero-example-promise.davesnx.workers.dev)): sequential and concurrent waits.
- [React rendering](examples/react/) ([demo](https://workero-example-react.davesnx.workers.dev)): server-side rendering in OCaml.
