# Development

`make help` lists the targets. Run `make build` to build the library, CLI, and
examples. Run `make fmt` to format the code, and `make test` to run the unit,
worker, worker-init, worker-exports, and CLI tests.

## Tests

- Unit tests in `test/unit/` are Alcotest executables built with `(modes js)`
  and run by Node through `dune test` (`make test-unit`). They use the JavaScript
  backend, not the Wasm worker runtime. Add a case to the relevant
  `test/unit/test_*.ml` file and its `Alcotest.run` list. For a new test module,
  add its name to `test/unit/dune` with the required libraries. Test code that
  awaits a Promise in a worker test instead; Node and JSPI support depends on
  the Node version, and these unit executables do not exercise the Wasm path.
- Worker tests in `test/worker/` run with `make test-worker`. This builds
  `test/worker/main.ml` with `workero build` and runs `test/worker/tests.mjs`
  in `workerd test` without a port. The worker is bound as `env.WORKER`, with
  `GREETING` set. Add a route to the relevant `test/worker/routes_*.ml` module
  (or `main.ml`), then add a case to the matching
  `test/worker/cases/*.mjs` suite. `tests.mjs` imports the suites. Cases can
  check `status`, `body`, `headers`, or `throws` for a handler that raises. A
  service binding rethrows where an HTTP request answers 500. Install
  `workerd` on `PATH` (CI uses `npm install -g workerd`). These tests run real
  Wasm in `workerd`, but KV, R2, and Cache use small JS test services in
  `test/worker/services/`. D1 uses a wrapped test adapter backed by Durable
  Object SQLite. They do not establish production storage-service behavior.
- Init tests in `test/worker-init/` run with `make test-worker-init`. They load
  a worker whose toplevel raises and expect the load to fail with the OCaml
  exception.
- Worker export tests in `test/worker-exports/` run with
  `make test-worker-exports`. They check which handlers each worker exports.
- CLI tests in `test/cli/` run with `make test-cli`. They check `workero build`
  and `workero package`, including arguments, output, and errors. Fixtures
  with missing wasm implementations must fail to build, with and without
  `--pretty`, unless `--allow-missing-primitives` is set.

## Documentation

Edit library API descriptions in the `.mli` files and guides in `doc/*.mld`.
Run `make docs` to generate HTML and Markdown with odoc; it copies Markdown to
`docs/`, directs symbol links to the HTML reference, and checks local links and
anchors. Do not edit generated `docs/` pages directly.

Run `make test-docs` to compile the OCaml examples extracted from the guides and
README, then run representative examples and the copied starter in `workerd`.
It installs the current library into a temporary prefix and builds the examples
outside the repository. Logs and packaged workers remain in `_build/doc-tests.*`.
