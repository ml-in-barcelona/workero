
# The project template

Copy `template/` outside the workero source checkout to start a Worker. Follow [Getting started](./getting_started.md) to install the source package and run the copy locally.


## Files

- `dune-project` requires OCaml 5\.4 or later and the `workero` package.
- `src/dune` builds `src/main.ml` with `(modes wasm)` and links `workero`.
- `src/main.ml` handles `GET /`, `POST /echo`, and `GET /env`.
- `wrangler.toml` points to `_worker/index.js`, runs `workero build src/main.bc.wasm.js`, watches `src/`, and sets `GREETING` in `[vars]`. It enables the `enable_request_signal` compatibility flag, so [`Workero.Request.signal`](./Workero-Request.md#val-signal) aborts when the client cancels.

## Run the copied project

After installing the source package and the opam `wrangler` package into your active switch, run these commands from your copy:

```sh
eval "$(opam env)"
opam exec -- wrangler dev
```
In another terminal, request `http://127.0.0.1:8787/`. Expect `Hello from OCaml on Cloudflare Workers`. Request `/env` to see `hello from vars`, the default `GREETING` value.

To deploy, first run `opam exec -- wrangler login` with a Cloudflare account, then `opam exec -- wrangler deploy`. You do not need an account for local `wrangler dev`.
