# workero

Write Cloudflare Workers in OCaml, compiled with wasm_of_ocaml.

- `lib/`: the `workero` library (`Workero.fetch`, `Request`, `Response`, `Env`, `URL`).
- `bin/`: the `workero` CLI. `workero build <dir>/<name>` writes a worker to `_worker/`.
- `examples/basic/`: a hello world worker that reports the OCaml version and backend.
- `examples/react/`: server-side React with `.mlx` components.
- `examples/limits/`: pushes the Workers limits with a CPU route and a memory route.
- `examples/bench.sh`: bundle size and response times for an example (`DIR=examples/react examples/bench.sh`).
- `template/`: a starter project to copy. See its README.
- `examples/hello/`, `examples/hello-jspi/`: the experiments that led here. Each one is its own dune project.

## Demos

- https://workero-example.davesnx.workers.dev (`examples/basic`): hello world, reports the OCaml version and backend.
- https://workero-example-react.davesnx.workers.dev (`examples/react`): a page rendered on the server from `.mlx` components.
- https://workero-example-limits.davesnx.workers.dev (`examples/limits`): `/cpu?n=1000&iter=500` renders a Mandelbrot set, `/memory?mb=200` allocates 200 MB. Raise the numbers until it fails.

## Size

Cloudflare limits a worker to 64 MiB uncompressed and sets no compressed limit ([limits](https://developers.cloudflare.com/workers/platform/limits/#worker-size)). The examples upload 96 to 123 KiB (31 to 40 KiB gzip).
