# workero

Write Cloudflare Workers in OCaml, compiled with wasm_of_ocaml.

- `lib/`: the `workero` library (`Workero.fetch`, `Request`, `Response`, `Env`, `URL`).
- `bin/`: the `workero` CLI. `workero build <dir>/<name>` writes a worker to `_worker/`.
- `examples/basic/`: a hello world worker that reports the OCaml version and backend.
- `examples/react/`: server-side React with `.mlx` components.
- `examples/bench.sh`: bundle size and response times for an example (`DIR=examples/react examples/bench.sh`).
- `template/`: a starter project to copy. See its README.
- `examples/hello/`, `examples/hello-jspi/`: the experiments that led here. Each one is its own dune project.
