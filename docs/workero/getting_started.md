
# Getting started

Write a Cloudflare Worker entirely in OCaml. workero compiles your program to WebAssembly with wasm\_of\_ocaml, and its library gives you the [runtime APIs](https://developers.cloudflare.com/workers/runtime-apis/): requests, responses, `fetch`, variables, secrets and cron triggers.

By following this guide you build a Worker, run it locally and deploy it.


## Prerequisites

- [opam](https://opam.ocaml.org) with OCaml 5\.4 or later.
- [Node.js](https://nodejs.org) and `npm`.
- `workero`, from opam: `opam install workero`.
- `wasm-opt` from binaryen 119 or later on `PATH`. wasm\_of\_ocaml runs it. The `binaryen` npm package provides it, and the template lists it as a dependency.

## 1\. Create a new project

Copy the `template/` directory of the repository. It is a complete project:

```sh
cp -r template my-worker
cd my-worker
npm install
```
`npm install` installs Wrangler, the Cloudflare tool that runs and deploys Workers, and `binaryen`. The project has these files:

- `dune-project`: the dune project. It depends on `workero`.
- `src/dune`: builds `src/main.ml` as an executable with `(modes wasm)`.
- `src/main.ml`: the Worker.
- `wrangler.toml`: the Wrangler configuration. It runs `workero build src/main` as the build command, and sets `GREETING` in `[vars]`.
- `package.json`: `wrangler` and `binaryen`.
See [the template](./template.md) for details.


## 2\. Develop locally

Run [`wrangler dev`](https://developers.cloudflare.com/workers/wrangler/commands/general/#dev) to start a local server:

```sh
npx wrangler dev
```
Wrangler runs `workero build src/main` and serves the Worker on [http://localhost:8787](http://localhost:8787). A change in `src/` triggers a rebuild. If you have not used Wrangler before, it opens a browser to log in to your Cloudflare account. See [`wrangler login`](https://developers.cloudflare.com/workers/wrangler/commands/general/#login) when you have no browser.

```sh
curl localhost:8787/
curl -d ping localhost:8787/echo
```

## 3\. Write your Worker code

The entry point is `src/main.ml`. It registers a handler with [`Workero.serve`](./Workero.md#val-serve):

```ocaml
let handler req env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" -> Response.text "Hello from OCaml on Cloudflare Workers\n"
  | POST, "/echo" -> Response.text (Request.text req)
  | GET, "/env" ->
      Response.text
        (Option.value (Env.var env "GREETING") ~default:"unset" ^ "\n")
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
[`Workero.serve`](./Workero.md#val-serve) takes a function with the same three arguments as the JavaScript `fetch(request, env, ctx)` handler. It runs in direct style, so `Request.text` and `Workero.fetch` return values, not promises. The next pages explain each part:

- [Handlers](./handlers.md): `serve`, `scheduled`, and the arguments of a handler.
- [Requests and responses](./requests.md): read a request, build a response, call other servers, read and write JSON.
- [Variables and secrets](./env.md).
- [Waiting for JavaScript](./async.md): `Promise.await` and background work.
- [Logging](./logging.md).

## 4\. Deploy

Deploy to a `*.workers.dev` subdomain, or to a [Custom Domain](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/) if you have one. Wrangler asks you to set up a subdomain the first time.

```sh
npx wrangler deploy
```
Preview the Worker at `<your-worker>.<your-subdomain>.workers.dev`. The first deploy to a new subdomain can answer with [523](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/error-523/) errors until DNS propagates, which takes about a minute.

You now have an OCaml Worker deployed. To learn how it works, read [How it works](./how_it_works.md). To test it, read [Testing and limits](./testing.md).
