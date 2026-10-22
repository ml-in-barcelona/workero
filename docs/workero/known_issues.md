
# Support and known issues

Behavior that differs from JavaScript Workers and native OCaml, and features not supported yet.


## Differences from JavaScript Workers

- A handler waits only through [`Workero.Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch) and the body readers. A function that JavaScript calls, such as a `setTimeout` callback, cannot wait. See [Waiting for JavaScript](./async.md).
- [`Workero.URL`](./Workero-URL.md) uses the WHATWG `URL`, but [`Workero.URL.path`](./Workero-URL.md#val-path) is decoded and only `http` and `https` URLs parse. See [Requests and responses](./requests.md).
- A response cannot have a status below 200 or above 599\. The runtime rejects them, so [`Workero.Status`](./Workero-Status.md) has ``Continue` and ``Switching_Protocols` only to read codes; use [`Workero.Websocket`](./Workero-Websocket.md) for 101\.

## Limits of streams, forms and WebSockets

- A client disconnect shows only as a failed [`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write).
- [`Workero.Response.copy`](./Workero-Response.md#val-copy) and [`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) use up the original body. Call [`Workero.Response.clone`](./Workero-Response.md#val-clone) first to keep it.
- [`Workero.Request.form_data`](./Workero-Request.md#val-form_data) holds the whole upload in memory. See [Forms](./forms.md).

## Limits of bindings

- [Queues](./queue.md): a consumer cannot see the content type. [`Workero.Queue.Message.body_json`](./Workero-Queue-Message.md#val-body_json) on a `Text` body gives a JSON string, and the other readers raise `Invalid_argument` on a body of another type. A `v8` body is readable only through [`Workero.Queue.Message.body_js`](./Workero-Queue-Message.md#val-body_js), and a producer cannot send one.
- Queues: `send` and `send_batch` take only `delay_seconds`. The runtime checks the size limits. Dead letter queues and `max_retries` are set in `wrangler.toml`, not in code.
- [Rate limiter](./rate_limiter.md): the key is the only argument. The limit and period come from `wrangler.toml`. The count is per location and approximate.
- [Hyperdrive](./hyperdrive.md): connection details only. There is no `connect` and no query driver, so workero cannot read from the database yet. The host and password are valid only inside the running Worker. In `workerd` the host is a fake name with no database behind it.
- [Workers AI](./ai.md): no streaming answers and no gateway options. [`Workero.Ai.run`](./Workero-Ai.md#val-run) raises `Invalid_argument` on a stream.
- [Analytics Engine](./analytics_engine.md): `write` returns no result, and the runtime checks the limit of 20 blobs and 20 doubles. There is no query API.

## Limits of Durable Objects

- Only classes with SQLite storage work. A class listed in `new_classes` builds, then fails at run time with a JavaScript error. See [Durable Objects](./durable_objects.md).
- A stub supports `fetch` only. There are no RPC methods on a stub.
- Stored values are JSON. A `Date` that other code stores reads back as its ISO string and a `Map` as `{}`. A `BigInt` or a cyclic value raises `Invalid_argument`.
- The function given to `register` cannot call [`Workero.Promise.await`](./Workero-Promise.md#val-await). Load stored values in `~init`. Keep per-object state in closures.
- [`Workero.Durable_object.register`](./Workero-Durable_object.md#val-register) must run when the module starts. A `register` call that a condition skips is not exported.
- `workero build` needs `workerd`. The main module must be `index.js`.
- A `block_concurrency_while` function that raises resets the object.
- SQL: `Int` values are exact only between \-2^53 and 2^53; a larger integer reads back as a `Float`. A whole-number `REAL` such as `2.0` reads back as `Int`. There is no asynchronous transaction. `Sql.run` gives the number of rows written only.
- [WebSockets](./websockets.md): a socket from [`Workero.Websocket.accept`](./Workero-Websocket.md#val-accept) does not hibernate. Do not mix it with `accept_websocket`. A class without `websocket_message` accepts hibernatable sockets and drops their messages.
- `workerd` cannot test hibernation (eviction and re-creation), jurisdictions, or the tag and 2048-byte attachment limits.

## Not supported yet

- The `tail` and `email` handlers.
- Workflows.
- RPC: `WorkerEntrypoint` and RPC methods on Durable Object stubs.
- Durable Objects without SQLite storage, and `State.container`.
- Vectorize and the Send Email binding.
- `HTMLRewriter`.
- Outbound TCP sockets (`connect`). [`Workero.Hyperdrive`](./Workero-Hyperdrive.md) gives connection details, but no OCaml database driver can use them yet.
- `AbortController` and request cancellation.
- `crypto.subtle`. [`Workero.Crypto`](./Workero-Crypto.md) has `random_uuid` and `random_bytes` only.
- Containers.

## Differences from native OCaml

- `Sys.word_size` is 32, and `int` has 31 bits.
- There is no file system, except files that you embed. See [Supported libraries](./libraries.md).
- The program has no threads, sockets or sub-processes.

## Report a problem

Open an issue in the [workero repository](https://github.com/ml-in-barcelona/workero). Include the OCaml, wasm\_of\_ocaml and Wrangler versions, and the smallest worker that shows the problem.
