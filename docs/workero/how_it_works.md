
# How it works

A workero Worker is a WebAssembly module that a small JavaScript entry point loads and calls. You write only OCaml.


## Compilation: wasm\_of\_ocaml

`(modes wasm)` in your `dune` file makes dune compile the OCaml bytecode with [wasm\_of\_ocaml](https://ocsigen.org/js_of_ocaml/). It gives a loader (`<name>.bc.wasm.js`) and a directory of `.wasm` files (`<name>.bc.wasm.assets`). OCaml 5 effects work in this backend.


## JavaScript plumbing

A Worker has to import its `.wasm` files, because the runtime gives a precompiled `WebAssembly.Module` and does not allow compiling wasm from bytes. `workero build` writes two files for this into `_worker/`:

- `load-wasm.js` gives the wasm\_of\_ocaml loader the precompiled modules and waits for OCaml initialisation.
- `index.js` imports every `.wasm` file, calls the loader, and exports the handlers that your program registered. See [Handlers](./handlers.md).
`workero build` runs the program once in `workerd` to discover registered Durable Object, entrypoint and Workflow classes. It adds a named export for each class to `index.js` and writes a glue file for each kind of class: `durable-object.js`, `entrypoint.js` or `workflow.js`. The glue calls the OCaml code that registered the class. Register the classes at module initialization, or the build does not see them. See [Entrypoints](./entrypoints.md) and [Workflows](./workflows.md).

`durable-object.js` routes object creation, fetch, alarm, RPC and hibernatable WebSocket events to the OCaml handlers. On each object creation, the JavaScript class calls the registered OCaml factory, installs the available event handlers and runs the optional `~init` handler under `blockConcurrencyWhile` before events. If the runtime evicts an object with hibernatable sockets, it creates the object again when a socket event arrives. In-memory state is lost; socket attachments can retain per-socket JSON state. See [Durable Objects](./durable_objects.md).

The OCaml library reaches the runtime APIs (`Request`, `Response`, `fetch`, bindings) through `Js_of_ocaml`. Workero converts between OCaml values and JavaScript objects. For APIs without a wrapper, see [JavaScript interop](./interop.md).


## Waiting for JavaScript

A Worker isolate has one JavaScript thread and event loop. Its WebAssembly module loads once per isolate, and many requests can use it. JavaScript I/O returns Promises; WebAssembly cannot block the thread while one settles.

Workero runs each handler in an OCaml 5 effect handler. When [`Workero.Promise.await`](./Workero-Promise.md#val-await) performs an effect, that handler captures the rest of the OCaml call as a continuation. It attaches callbacks to the Promise and returns control to the JavaScript event loop, so other requests can progress. On fulfillment, a callback resumes the continuation with the value. On rejection, it resumes by raising the error. The handler can suspend again. When the handler returns or raises, its outer Promise settles. A fetch handler returns a [`Workero.Response.t`](./Workero-Response.md#type-t); scheduled, queue, email, alarm and Durable Object WebSocket event handlers return `unit`. The runtime handles the result or error.

wasm\_of\_ocaml implements these effects with WebAssembly's JavaScript Promise Integration (JSPI). The suspended continuation includes a WebAssembly stack. WebAssembly can suspend only when JavaScript enters it through a `WebAssembly.promising` function. The entry into each handler and every resume use this boundary. Workero handles this mechanism; handler code uses direct style. See [Async and background work](./async.md) for practical use and limits.

The synchronous [`Workero.Durable_object.Storage.transaction_sync`](./Workero-Durable_object-Storage.md#val-transaction_sync) callback cannot suspend. Workero rejects [`Workero.Promise.await`](./Workero-Promise.md#val-await) in that callback with `Invalid_argument`, and the runtime rolls back the transaction.


## Bundling: workero build

`workero build src/main.bc.wasm.js` builds the executable (in the release profile unless you pass another profile), checks that it has no missing primitives, and writes the directory that Wrangler bundles and deploys. See [the CLI](./cli.md). The template runs it as the `[build]` command of `wrangler.toml`.


## Binary optimization: wasm-opt

wasm\_of\_ocaml runs `wasm-opt` from binaryen on the output, which is why binaryen must be on `PATH`. Adding libraries can increase the module size. See [Limits](./limits.md) for current platform limits.
