
# The project template

The `template/` directory of the repository is a starter project for a Cloudflare Worker written in OCaml. Copy it to start a new worker.


## Files

- `dune-project`: a package that depends on `workero`.
- `src/dune`: the executable `main`, built with `(modes wasm)`.
- `src/main.ml`: the worker.
- `wrangler.toml`: runs `workero build src/main` as the build command (see [the CLI](./cli.md)) and sets `GREETING` in `[vars]`.
- `package.json`: `wrangler` and `binaryen` as development dependencies.

## Start

```sh
opam install workero
npm install          # wrangler, and binaryen for wasm_of_ocaml
npx wrangler dev     # builds src/main.ml, serves on localhost:8787
npx wrangler deploy
```

## The worker

```ocaml
let handler req env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" -> Response.text "Hello from OCaml on Cloudflare Workers\n"
  | POST, "/echo" -> Response.text (Request.body_text req)
  | GET, "/env" ->
      Response.text
        (Option.value (Env.var env "GREETING") ~default:"unset" ^ "\n")
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
```
Routes: `GET /`, `POST /echo`, and `GET /env`, which reads `GREETING` with [`Workero.Env.var`](./Workero-Env.md#val-var).
