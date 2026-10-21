
# Getting started

Build a Cloudflare Worker in OCaml, run it locally, change its response, and deploy it. This guide starts outside the workero repository.


## Prerequisites

- [opam](https://opam.ocaml.org/doc/Install.html) with an active OCaml 5\.4 or later switch. The source package requires Dune 3\.24 or later, `js_of_ocaml` and `wasm_of_ocaml-compiler` 6\.4.1 or later and below 6\.5, and `jsonkit` 1\.1 or later and below 2\. The source installation below lets opam resolve these dependencies.
- [Git](https://git-scm.com/) to clone the source.
- [Node.js](https://nodejs.org/) 22 or later with npm. The template installs Wrangler 4\.151.3 and binaryen 132 with `npm install`. binaryen supplies `wasm-opt`, which wasm\_of\_ocaml needs on `PATH`.
There is no published `workero` package on the opam package index yet. Install it from this repository instead. You need a Cloudflare account only for the deployment step.


## 1\. Create a project

From a directory outside any Dune project, clone workero, install its package into your active opam switch, and copy its template into a sibling directory:

```sh
eval "$(opam env)"
git clone https://github.com/ml-in-barcelona/workero.git workero-source
opam pin add workero ./workero-source -y
cp -R workero-source/template my-worker
cd my-worker
npm install
```
The `opam pin add` command installs the `workero` library and CLI from the clone. `npm install` installs Wrangler and binaryen in `node_modules`. Keep `my-worker` outside `workero-source` because Dune selects an outer project root when projects are nested.

The new project contains `dune-project`, `src/dune`, `src/main.ml`, `wrangler.toml`, and `package.json`. See [The project template](./template.md) for each file's role.


## 2\. Run locally

Start Wrangler from `my-worker`:

```sh
npx wrangler dev
```
Wrangler runs `workero build src/main.bc.wasm.js`, writes the packaged Worker to `_worker/`, and starts a local server. Look for its URL in the output, usually `http://127.0.0.1:8787`. You do not need to log in to run locally. Leave the server running and use a second terminal for these requests:

```sh
curl http://127.0.0.1:8787/
curl -d ping http://127.0.0.1:8787/echo
curl http://127.0.0.1:8787/env
```
The first response is `Hello from OCaml on Cloudflare Workers`, the second is `ping`, and the third is `hello from vars`. The `GREETING` value comes from `[vars]` in `wrangler.toml`.


## 3\. Write a response

Replace `src/main.ml` with this handler. It retains the existing routes and changes the home page response:

```ocaml
let handler req env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" -> Response.text "Hello from my worker\n"
  | POST, "/echo" -> Response.text (Request.text req)
  | GET, "/env" ->
      Response.text
        (Option.value (Env.var env "GREETING") ~default:"unset" ^ "\n")
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
Wrangler watches `src/` and rebuilds after you save. Run `curl http://127.0.0.1:8787/` again. The response is now `Hello from my worker`. [`Workero.serve`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-serve) registers the handler; [Runtime APIs](./runtime_apis.md) lists the available request, response, and network functions. [Bindings](./bindings.md) covers configuration and resources.


## 4\. Deploy

Create a [Cloudflare account](https://dash.cloudflare.com/sign-up) if you do not have one. From `my-worker`, authenticate Wrangler, then deploy:

```sh
npx wrangler login
npx wrangler deploy
```
The login command opens a browser for authentication. Wrangler builds and uploads the Worker, then prints its public URL, usually `https://workero-demo-template.<your-subdomain>.workers.dev`. Open that URL or request it with `curl` to see `Hello from my worker`. Your first deployment may ask you to set up a `workers.dev` subdomain. Unlike local development, deployment needs account authentication.

Next, read [Handlers](./handlers.md), [Variables and secrets](./env.md), and [The workero CLI](./cli.md).
