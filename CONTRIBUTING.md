# Development

`make help` lists the targets. Run `make build` to build the library, CLI, and
examples. Run `make fmt` to format the code, and `make test` to run the unit,
worker, worker-init, worker-exports, worker-tail, and CLI tests.

## Tests

- Unit tests in `test/unit/` are Alcotest executables built with `(modes js)`
  and run by Node through `dune test` (`make test-unit`). Add a case to the
  relevant `test/unit/test_*.ml` file and its `Alcotest.run` list. Add new test
  modules in `test/unit/dune`. These unit tests do not exercise Wasm or the
  worker runtime; put code that awaits a Promise in a worker test.
- Worker tests in `test/worker/` run with `make test-worker`. This builds
  `test/worker/main.ml` with `workero build` and runs `test/worker/tests.mjs`
  in `workerd test` without a port. The worker is bound as `env.WORKER`, with
  `GREETING` set. Add a route to the matching `test/worker/routes_*.ml`
  module (or `main.ml`) and a case to `test/worker/cases/*.mjs`.
  `tests.mjs` imports those suites. Check `status`, `body`, `headers`, or `throws`
  for a handler that raises. A service binding rethrows where HTTP answers
  500. `workerd` must be on `PATH`; `npm install workerd` or `wrangler`
  provides it. KV, R2, and Cache bindings point at small JS services in
  `test/worker/services/`. D1 uses a wrapped test adapter backed by Durable
  Object SQLite. These substitutes test the binding interface, not Cloudflare
  production storage. The
  Queue producer binding points at an HTTP service that records what the
  runtime sends. Rate limiter, AI and Analytics Engine are `wrapped` stubs.
  Durable Object classes are registered in `test/worker/routes_do.ml`; the config
  gives the worker on-disk storage for them, because SQLite needs it.
  Queue consumer cases run in a second test service, `test-queue`
  (`tests_queue.mjs`), because `env.WORKER.queue(...)` needs the
  `service_binding_extra_handlers` compatibility flag, which changes how
  `scheduled` reports a failure, and `workerd test --experimental`.
- Init tests in `test/worker-init/` run with `make test-worker-init`. They build
  a worker whose toplevel raises and expect the build-time `workerd` probe to
  fail with the OCaml exception.
- Worker export tests in `test/worker-exports/` run with
  `make test-worker-exports`. They check which handlers each worker exports.
- Tail tests in `test/worker-tail/` run with `make test-worker-tail`. The OCaml
  program in `main.ml` registers `Workero.tail` and posts a summary of each
  trace item to a JavaScript sink. `producer.mjs` is a JavaScript Worker that
  lists it in `tails` and answers fetch, scheduled and queue calls.
  `tests.mjs` calls the producer, polls the sink and checks the summaries. It
  reads each producer response body: the tail event arrives only after the
  response ends.
- CLI tests in `test/cli/` run with `make test-cli`. They check `workero build`
  and `workero package`, including arguments, output, class discovery,
  initialization timeouts, and errors. Fixtures
  with missing wasm implementations must fail to build, with and without
  `--pretty`, unless `--allow-missing-primitives` is set.

## Documentation

Edit library API descriptions in the `.mli` files and guides in `doc/*.mld`.
Run `make docs` to generate HTML and Markdown with odoc; it copies Markdown to
`docs/`. Do not edit generated `docs/` pages directly.
