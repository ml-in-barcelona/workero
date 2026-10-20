# workero

Write Cloudflare Workers in OCaml, compiled with wasm_of_ocaml.

- `lib/`: the `workero` library (`Workero.fetch`, `Request`, `Response`, `Env`, `URL`).
- `bin/`: the `workero` CLI. `workero build <dir>/<name>` writes a worker to `_worker/`.
- `example/`: an example worker.
- `template/`: a starter project to copy. See its README.
- `hello/`, `hello-jspi/`: the experiments that led here. Each one is its own dune project.
