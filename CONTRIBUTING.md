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
  500. `workerd` must be on `PATH`; `opam install workerd`, `npm install workerd`
  or `wrangler` provides it. KV, R2, and Cache bindings point at small JS services in
  `test/worker/services/`. D1 is a `wrapped` binding over SQLite there.
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
The docs of `workerd` and `wrangler` are `workerd/index.mld` and
`wrangler/index.mld`. Run `make docs` to generate HTML and Markdown with odoc;
it copies Markdown to `docs/`. Do not edit generated `docs/` pages directly.

## Releasing workero

Add the changes to `CHANGES.md` and push a tag such as `1.0.0` or `v1.0.0`.
`ci.yml` releases `workero` with `dune-release` on these tags only.

## Releasing workerd and wrangler

The opam packages `workerd` and `wrangler` have their own version, changelog
and tag. They are in the directories `workerd/` and `wrangler/`. Their opam
files are not at the repository root, because dune needs one `(package)`
stanza for each opam file there.

- `workerd/workerd.opam` and `workerd/platform/*.opam` install the prebuilt
  workerd binary. The version is the version of the npm package `workerd`.
- `wrangler/wrangler.opam` installs a bundle of wrangler. The version is the
  version of the npm package `wrangler`. It depends on the exact workerd version
  that wrangler pins.

To release:

1. Run `node scripts/workerd-opam.ts <version>` or
   `node scripts/wrangler-opam.ts <version>`. They fetch the npm metadata and
   rewrite the opam files. Node.js 22.18 or later runs them.
2. Add a `## <version>` section to `workerd/CHANGES.md` or
   `wrangler/CHANGES.md`. For a new wrangler, release the workerd version that
   it pins first.
3. Commit, then push the tag `workerd-<version>` or `wrangler-<version>`.

`release-binaries.yml` starts on these tags. It makes a GitHub release with the
changes of that version, and opens a pull request on `ocaml/opam-repository`
from your fork. For wrangler, it builds the bundle first
(`scripts/wrangler-bundle.ts`), attaches it to the release, and uses it as the
`url` of the opam file. `dune-release` does not release these packages: it
sets the `url` to a tarball of this repository, and `davesnx/dune-release-action`
reads the whole tag as the version.
