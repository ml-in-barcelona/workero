
# How it works

A workero Worker is a WebAssembly module that a small JavaScript entry point loads and calls. You write only OCaml.


## Compilation: wasm\_of\_ocaml

`(modes wasm)` in your `dune` file makes dune compile the OCaml bytecode with [wasm\_of\_ocaml](https://ocsigen.org/js_of_ocaml/). It gives a loader (`<name>.bc.wasm.js`) and a directory of `.wasm` files (`<name>.bc.wasm.assets`). OCaml 5 effects work in this backend.


## JavaScript plumbing

A Worker has to import its `.wasm` files, because the runtime gives a precompiled `WebAssembly.Module` and does not allow compiling wasm from bytes. `workero build` writes two files for this into `_worker/`:

- `load-wasm.js` gives the wasm\_of\_ocaml loader the precompiled modules and waits for OCaml initialisation.
- `index.js` imports every `.wasm` file, calls the loader, and exports the handlers that your program registered. See [Handlers](./handlers.md).
The OCaml library reaches the runtime APIs (`Request`, `Response`, `fetch`, bindings) through `Js_of_ocaml`. Workero converts between OCaml values and JavaScript objects. For APIs without a wrapper, see [JavaScript interop](./interop.md).


## Waiting for JavaScript

A Worker isolate has one JavaScript thread and event loop. Its WebAssembly module loads once per isolate, and many requests can use it. JavaScript I/O returns Promises; WebAssembly cannot block the thread while one settles.

Workero runs each handler in an OCaml 5 effect handler. When [`Workero.Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await) performs an effect, that handler captures the rest of the OCaml call as a continuation. It attaches callbacks to the Promise and returns control to the JavaScript event loop, so other requests can progress. On fulfillment, a callback resumes the continuation with the value. On rejection, it resumes by raising the error. The handler can suspend again. When the handler returns a [`Workero.Response.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#type-t) or raises, its outer Promise settles and the runtime handles the response or error.

wasm\_of\_ocaml implements these effects with WebAssembly's JavaScript Promise Integration (JSPI). The suspended continuation includes a WebAssembly stack. WebAssembly can suspend only when JavaScript enters it through a `WebAssembly.promising` function. The entry into each handler and every resume use this boundary. Workero handles this mechanism; handler code uses direct style. See [Async and background work](./async.md) for practical use and limits.


## Bundling: workero build

`workero build src/main.bc.wasm.js` builds the executable (in the release profile unless you pass another profile), checks that it has no missing primitives, and writes the directory that Wrangler bundles and deploys. See [the CLI](./cli.md). The template runs it as the `[build]` command of `wrangler.toml`.


## Binary optimization: wasm-opt

wasm\_of\_ocaml runs `wasm-opt` from binaryen on the output, which is why binaryen must be on `PATH`. Adding libraries can increase the module size. See [Limits](./limits.md) for current platform limits.
