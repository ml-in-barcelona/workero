
# Getting started

Build a Cloudflare Worker in OCaml, run it locally, then change its response. Start outside the workero source checkout so Dune treats your Worker as its own project. Deployment is optional and needs a Cloudflare account.


## Prerequisites

- [opam](https://opam.ocaml.org/doc/Install.html) with an active OCaml 5\.4 or later switch. The source package requires Dune 3\.24 or later, `js_of_ocaml` and `wasm_of_ocaml-compiler` 6\.4.1 or later and below 6\.5, and `jsonkit` 1\.1 or later and below 2\. opam resolves these dependencies.
- Git to clone workero.
- Node.js 22 or later with npm to install Wrangler and binaryen. binaryen supplies `wasm-opt`, which wasm\_of\_ocaml needs on `PATH`.
The `workero` package is not yet available from the opam package index. Install it from source instead.


## 1\. Create a project

From a directory outside any Dune project, clone workero and install its package into your active switch. Copy the template into a sibling directory:

```sh
eval "$(opam env)"
git clone https://github.com/ml-in-barcelona/workero.git workero-source
opam pin add workero ./workero-source -y
cp -R workero-source/template my-worker
cd my-worker
npm install
```
The pin installs the `workero` library and CLI. `npm install` installs Wrangler and binaryen in `node_modules`. Keep `my-worker` outside `workero-source` so Dune does not select the source checkout as the project root. See [The project template](./template.md) for the files in your copy.


## 2\. Run locally

Start Wrangler from `my-worker`:

```sh
npx wrangler dev
```
Wrangler runs `workero build src/main.bc.wasm.js`, packages the Worker in `_worker/`, and prints a local URL, usually `http://127.0.0.1:8787`. Leave the server running. In another terminal, request the template's routes:

```sh
curl http://127.0.0.1:8787/
curl -d ping http://127.0.0.1:8787/echo
curl http://127.0.0.1:8787/env
```
Expect `Hello from OCaml on Cloudflare Workers`, `ping`, and `hello from vars`, in that order. The third value comes from `[vars]` in `wrangler.toml`. Local development does not require Cloudflare login.


## 3\. Change the home page

Open `src/main.ml` and change the `GET, "/"` branch to:

```ocaml
| GET, "/" -> Response.text "Hello from my worker\n"
```
Wrangler watches `src/` and rebuilds after you save. Request the root path again:

```sh
curl http://127.0.0.1:8787/
```
Expect `Hello from my worker`. The template registers the handler with [`Workero.serve`](./Workero.md#val-serve). Continue with [Runtime APIs](./runtime_apis.md) for HTTP, JSON, and handlers, or [Bindings](./bindings.md) for Cloudflare resources.


## 4\. Deploy (optional)

If you have a Cloudflare account and want a public Worker, authenticate and deploy from `my-worker`:

```sh
npx wrangler login
npx wrangler deploy
```
Wrangler prints the public URL. It may ask you to set up a `workers.dev` subdomain on your first deployment. Request that URL to see `Hello from my worker`. See [CLI](./cli.md) for packaging details.
