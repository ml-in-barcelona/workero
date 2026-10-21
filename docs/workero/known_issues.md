
# Support and known issues

Behavior that differs from JavaScript Workers and native OCaml, and features not supported yet.


## Differences from JavaScript Workers

- Await only in the supported handler contexts. A function that JavaScript calls, such as a `setTimeout` callback, cannot await. See [Async and background work](./async.md) for those contexts.
- [`Workero.URL`](./Workero-URL.md) uses the WHATWG `URL`, but [`Workero.URL.path`](./Workero-URL.md#val-path) is decoded and only `http` and `https` URLs parse. See [URLs](./url.md).
- A response cannot have a status below 200 or above 599\. The runtime rejects them, so [`Workero.Status`](./Workero-Status.md) has ``Continue` and ``Switching_Protocols` only to read codes; use [`Workero.Websocket`](./Workero-Websocket.md) for 101\.

## Limits of streams, forms and WebSockets

- Workero has no client-disconnect callback for a streamed response. A [`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) can reject when the client disconnects.
- [`Workero.Response.copy`](./Workero-Response.md#val-copy) and [`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) share the original body stream. It can be consumed only once. Call [`Workero.Response.clone`](./Workero-Response.md#val-clone) before reading if you need two copies.
- [`Workero.Request.form_data`](./Workero-Request.md#val-form_data) holds the whole upload in memory. See [Forms](./forms.md).

## Binding limits

- [Queues](./queue.md): consumers do not receive the content type. [`Workero.Queue.Message.body_json`](./Workero-Queue-Message.md#val-body_json) on a `Text` body gives a JSON string. The other readers require compatible JavaScript value types and raise `Invalid_argument` for incompatible values. A `v8` body can be read only through [`Workero.Queue.Message.body_js`](./Workero-Queue-Message.md#val-body_js); workero producers cannot send `v8`. `send` and `send_batch` expose `delay_seconds`, but no other send options. The runtime checks message size. Configure dead letter queues and `max_retries` in `wrangler.toml`.
- [Rate limiter](./rate_limiter.md): the key is the only call argument. Set the limit and period in `wrangler.toml`. Counts are per location and approximate.
- [Workers AI](./ai.md): streaming answers and gateway options are not supported. [`Workero.Ai.run`](./Workero-Ai.md#val-run) raises `Invalid_argument` for a stream.
- [Analytics Engine](./analytics_engine.md): `write` returns no result. The runtime checks the limits of 20 blobs and 20 doubles. There is no query API.

## Durable Object limits

- The storage API requires a SQLite-backed class. A class listed in `new_classes` can build, but its key-value and SQL calls fail at runtime. See [Durable Objects](./durable_objects.md).
- A stub supports `fetch` only. There are no RPC methods on a stub.
- Stored values are JSON. A `Date` that other code stores reads back as its ISO string and a `Map` as `{}`. A `BigInt` or a cyclic value raises `Invalid_argument`.
- The function given to `register` cannot call [`Workero.Promise.await`](./Workero-Promise.md#val-await). Load stored values in `~init`. Keep per-object state in closures.
- [`Workero.Durable_object.register`](./Workero-Durable_object.md#val-register) must run when the module starts. A `register` call that a condition skips is not exported.
- `workero build` needs `workerd`. The main module must be `index.js`.
- A `block_concurrency_while` function that raises resets the object.
- SQL: `Int` values are exact only within ±`2^53`; a larger integer can read back as a `Float`. A whole-number `REAL` such as `2.0` reads back as `Int`. There is no asynchronous transaction. `Sql.run` returns only the number of rows written. [`Workero.Durable_object.Storage.transaction_sync`](./Workero-Durable_object-Storage.md#val-transaction_sync) rejects [`Workero.Promise.await`](./Workero-Promise.md#val-await) with `Invalid_argument` and rolls back.
- [WebSockets](./websockets.md): a socket accepted with [`Workero.Websocket.accept`](./Workero-Websocket.md#val-accept) does not hibernate. Do not also call [`Workero.Durable_object.State.accept_websocket`](./Workero-Durable_object-State.md#val-accept_websocket) on that socket. A class without `websocket_message` can accept hibernatable sockets, but does not handle their messages.
- The `workerd` tests cannot prove eviction and re-creation during hibernation, jurisdictions, or the tag and 2048-byte attachment limits. Test these in a deployed Worker.

## Not supported yet

- The `tail` and `email` handlers.
- Workflows.
- RPC: `WorkerEntrypoint` and RPC methods on Durable Object stubs.
- Durable Objects without SQLite storage, and `State.container`.
- Vectorize, Hyperdrive and the Send Email binding.
- `HTMLRewriter`.
- Outbound TCP sockets (`connect`).
- `AbortController` and request cancellation.
- `crypto.subtle`. [`Workero.Crypto`](./Workero-Crypto.md) has `random_uuid` and `random_bytes` only.
- Containers.

## Differences from native OCaml

- `Sys.word_size` is 32, and `int` has 31 bits.
- There is no file system, except files that you embed. See [Supported libraries](./libraries.md).
- The program has no threads, sockets or sub-processes.
Successful compilation does not prove that a library's runtime dependencies are available in a Worker. See [Supported libraries](./libraries.md) and [Testing a worker](./testing.md).


## Report a problem

Open an issue in the [workero repository](https://github.com/ml-in-barcelona/workero). Include the OCaml, wasm\_of\_ocaml and Wrangler versions, and the smallest worker that shows the problem.
