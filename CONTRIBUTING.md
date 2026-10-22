# Development

`make help` lists the targets. Run `make build` to build the library, CLI, and
examples. Run `make fmt` to format the code, and `make test` to run the unit,
worker, worker-init, worker-exports, and CLI tests.

## Tests

- Unit tests in `test/unit/` are alcotest executables built with `(modes js)`
  and run by Node through `dune test` (`make test-unit`). They cover code that
  does not await, such as `Workero.URL`. Alcotest has no wasm runtime, and Node
  22 has no JSPI, so code that uses `Promise.await` cannot run here. To add a
  test, write a function in `test/unit/test_workero.ml` and list it in
  `Alcotest.run`. A new file needs its own `(test (name ...) (modules ...)
  (modes js) (libraries workero alcotest))` stanza.
- Worker tests in `test/worker/` run with `make test-worker`. This builds
  `test/worker/main.ml` with `workero build` and runs `test/worker/tests.mjs`
  in `workerd test` without a port. The worker is bound as `env.WORKER`, with
  `GREETING` set. To add a test, add a route to `test/worker/main.ml` and a
  case to `cases` in `tests.mjs`. Check `status`, `body`, `headers`, or `throws`
  for a handler that raises. A service binding rethrows where HTTP answers
  500. `workerd` must be on `PATH`; `npm install workerd` or `wrangler`
  provides it. KV, R2, and Cache bindings point at small JS services in
  `test/worker/services/`. D1 is a `wrapped` binding over SQLite there. The
  Queue producer binding points at an HTTP service that records what the
  runtime sends. Rate limiter, AI and Analytics Engine are `wrapped` stubs.
  Durable Object classes are registered in `test/worker/routes_do.ml`; the config
  gives the worker on-disk storage for them, because SQLite needs it.
  Queue consumer cases run in a second test service, `test-queue`
  (`tests_queue.mjs`), because `env.WORKER.queue(...)` needs the
  `service_binding_extra_handlers` compatibility flag, which changes how
  `scheduled` reports a failure, and `workerd test --experimental`.
- Init tests in `test/worker-init/` run with `make test-worker-init`. They build
  a worker whose toplevel raises and expect the build to fail with the OCaml
  exception. `workero build` runs the program in `workerd` to find its Durable
  Object classes, so an initialisation error stops the build.
- Worker export tests in `test/worker-exports/` run with
  `make test-worker-exports`. They check which handlers each worker exports.
- CLI tests in `test/cli/` run with `make test-cli`. They check `workero build`
  and `workero package`, including arguments, output, and errors. Fixtures
  with missing wasm implementations must fail to build, with and without
  `--pretty`, unless `--allow-missing-primitives` is set.

## Documentation

Edit library API descriptions in the `.mli` files and guides in `doc/*.mld`.
Run `make docs` to generate HTML and Markdown with odoc; it copies Markdown to
`docs/`. Do not edit generated `docs/` pages directly.
