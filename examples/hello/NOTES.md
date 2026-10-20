# Notes: wasm_of_ocaml in workerd

Historical: written for the standalone experiment (own dune project, `mk-worker.sh`, `dev.sh`, `load-wasm.js`, `eff.ml`). That project is now `examples/hello/main.ml`, built by `workero build`, whose CLI embeds `load-wasm.js` (`bin/load-wasm.js`, identical to the experiment copy) and `Workero.Promise.await`.

Versions: OCaml 5.5.1, dune 3.24.2, js_of_ocaml / wasm_of_ocaml-compiler 6.4.1, binaryen 132 (npm),
ocamlformat 0.29.0, ocaml-lsp-server 1.27.0, wrangler 4.151.3, workerd 1.20261019.1, node 22.22.3.
compatibility_date 2026-10-01, no compatibility flags.

Environment: sandbox made ~/.opam read-only, so opam root is local (.opam-root).
opam needs `opam option depext=false` and npm's wasm-opt on PATH (conf-binaryen has no apt package here).
npm needs `--cache`, wrangler needs WRANGLER_LOG_PATH / XDG_CONFIG_HOME inside the project (dev.sh).
dune did not promote hello.opam inside the sandbox; copied from _build/default/hello.opam.

## Results
1. Build: `dune build --profile release` gives one file `code-<hash>.wasm`: main 55,797 B (gzip -9 19,720 B),
   eff 57,073 B (gzip 20,064 B). Loader JS 15.6 KB. Far below 3 MB limit. Dev profile gives many wasm files (~1.3 MB).
2. Node: loader works (`node main.bc.wasm.js`; export is async, call after a tick). Output:
   `hello from OCaml 5.5.1: sum=285; caught Boom 285; Not_found ok; 1.414` (exceptions OK).
3. Worker, unmodified loader (`import "./main.bc.wasm.js"`): the loader promise rejects silently, global `hello` undefined.
   Exposing the promise showed: `TypeError: Cannot read properties of undefined (reading 'filename')`
   (loader believes it is Node because process.versions.node exists in workerd, calls require.main.filename).
4. Probe in workerd: `new WebAssembly.Module(bytes)` -> `CompileError: Wasm code generation disallowed by embedder`.
   WebAssembly.promising, Suspending, JSTag, Tag all exist.
5. Loader shim (load-wasm.js): the generated loader is not edited.
   index.js (made by mk-worker.sh) imports every `*.wasm` in the assets dir (wrangler gives precompiled Modules)
   and calls `loadWasmOCaml(modules, () => import("./<n>.bc.wasm.js"))`, which for the duration of the load:
   - hides `globalThis.process`, so the loader takes its browser path (no require.main.filename);
   - replaces `fetch` (loader calls it with `<src>/<file>.wasm`) to return the matching Module;
   - replaces `WebAssembly.instantiateStreaming` to call `WebAssembly.instantiate(Module, imports)` and return `{instance}`;
   - wraps `WebAssembly.promising` for the `_initialize` export, to know when OCaml init has finished
     (the loader promise is not exported).
   - captures `caml_callback` from the instantiated exports (last instance exporting it wins, like the loader's
     Object.assign) and defines `globalThis.__promisify` (see 7).
   The shims are restored after init; `__promisify` stays. Works for dev (10 wasm files) and release (1 file) builds, no string matching.
   It relies on the loader's browser-path contract (fetch + instantiateStreaming, `_initialize` export) and on
   WebAssembly.promising existing (true in workerd). Import options (js-string builtins) are ignored for a
   precompiled Module; both profiles work, so the polyfill imports suffice here.
6. `wrangler dev --local`, curl: HTTP 200, same output as node. Latency: first request 8-11 ms (includes
   instantiate), later 4 ms. Not a true cold start measurement (no production).
7. Effects with default JSPI (no `--effects=cps`): the loader wraps `_initialize` and `caml_start_fiber` in
   `WebAssembly.promising`, but `Js.export` methods are called through the non-promising `caml_callback` export, so
   performing an effect there raises `SuspendError: trying to suspend without WebAssembly.promising`.
   Fix without a loader patch: load-wasm.js defines `globalThis.__promisify(f)`. It returns an async function that calls
   `WebAssembly.promising(caml_callback)(f, arity, args, 1)`; the result needs two awaits (the promise is not flattened in
   workerd). It must exist before OCaml init, because eff.ml wraps its exports (`promising run`) at toplevel.
   eff.ml wraps each exported function with it, and an `Await` effect handler resumes continuations inside a promising call,
   so `await (sleep 50)` can sit between effects. index.js awaits `hello.*()`.
   Results (dev and release): `/` -> `effects ok: 30`; `/await` -> `effects across awaited promises ok: 30 (~100 ms)`;
   `/fail` (exception after an Await) -> rejected promise, HTTP 500 `error: Dune__exe__Eff.Failed(30)`.
8. dune fmt clean; ocamllsp --version = 1.27.0.

## Unverified
Real Cloudflare deploy; production limits enforcement; true cold start; js-string builtins path with larger programs
(Str, Hashtbl, Format, Lwt); async JS interop and fetch from OCaml; other wasm_of_ocaml versions; effects in callbacks not wrapped by __promisify (still raise SuspendError); a runtime without WebAssembly.promising.

## Scratch (can be deleted): worker1..4, probe, nodetest, *.log, _opam (old 5.4.1 switch).
Current: worker-main, worker-eff.
