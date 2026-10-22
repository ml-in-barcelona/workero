
# Support and known issues

Behavior that differs from JavaScript Workers and native OCaml, and features not supported yet.


## Differences from JavaScript Workers

- Await only in the supported handler contexts. A function that JavaScript calls, such as a `setTimeout` callback, cannot await. See [Async and background work](./async.md) for those contexts.
- [`Workero.URL`](./Workero-URL.md) uses the WHATWG `URL`, but [`Workero.URL.path`](./Workero-URL.md#val-path) is decoded and only `http` and `https` URLs parse. See [URLs](./url.md).
- A response cannot have a status below 200 or above 599\. Workero raises `Invalid_argument` for such a status, also for ``Status 101`. So [`Workero.Status`](./Workero-Status.md) has ``Continue` and ``Switching_Protocols` only to read codes; use [`Workero.Websocket`](./Workero-Websocket.md) for 101\.

## Limits of streams, forms and WebSockets

- Workero has no client-disconnect callback for a streamed response. A [`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) can reject when the client disconnects.
- [`Workero.Response.copy`](./Workero-Response.md#val-copy) and [`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) share the original body stream. It can be consumed only once. Call [`Workero.Response.clone`](./Workero-Response.md#val-clone) before reading if you need two copies.
- [`Workero.Request.form_data`](./Workero-Request.md#val-form_data) holds the whole upload in memory. See [Forms](./forms.md).

## Binding limits

- [Queues](./queue.md): consumers do not receive the content type. [`Workero.Queue.Message.body_json`](./Workero-Queue-Message.md#val-body_json) on a `Text` body gives a JSON string. The other readers require compatible JavaScript value types and raise `Invalid_argument` for incompatible values. A `v8` body can be read only through [`Workero.Queue.Message.body_js`](./Workero-Queue-Message.md#val-body_js); workero producers cannot send `v8`. `send` and `send_batch` expose `delay_seconds`, but no other send options. Cloudflare checks message size; workero does not. Configure dead letter queues and `max_retries` in `wrangler.toml`.
- [Rate limiter](./rate_limiter.md): the key is the only call argument. Set the limit and period in `wrangler.toml`. Counts are per location and approximate.
- [Workers AI](./ai.md): streaming answers and gateway options are not supported. [`Workero.Ai.run`](./Workero-Ai.md#val-run) raises `Invalid_argument` for a stream.
- [Analytics Engine](./analytics_engine.md): `write` returns no result. Cloudflare checks the limits of 20 blobs and 20 doubles; workero does not. There is no query API.
- [Hyperdrive](./hyperdrive.md): connection details only. There is no query driver, so workero cannot read from the database yet. The host and password are valid only inside the running Worker. In `workerd` the host is a fake name with no database behind it.
- [Sockets](./socket.md): outbound connections only, from a handler. There is no `connect` handler for incoming TCP and no `Socket.upgraded`. [`Workero.Socket.opened`](./Workero-Socket.md#val-opened) gives no address information. `workerd` cannot test TLS: with a Worker as outbound, `secure_transport:On` and `start_tls` fail. Cloudflare limits the destination (no Cloudflare addresses, loopback or port 25\) and the number of open connections for each request; see its documentation.
- Sockets: `index.js` always imports `cloudflare:sockets`. It is available on Cloudflare and in `workerd` without a flag. A program run outside a Worker, for example in Node.js, raises `Failure` from [`Workero.Socket.connect`](./Workero-Socket.md#val-connect).
- [Email](./email.md): `workerd` has no way to deliver a test email, and it has no `cloudflare:email` module. [`Workero.Email.reply`](./Workero-Email.md#val-reply) fails there with a [`Workero.Js_error`](./Workero.md#exception-Js_error). The tests call the handler from a JavaScript harness with a mock message and a stand-in module, so they do not prove what the real runtime accepts.
- Email: [`Workero.Email.reply`](./Workero-Email.md#val-reply) takes the raw message as a string, not a stream. [`Workero.Email.raw_text`](./Workero-Email.md#val-raw_text) and [`Workero.Email.raw_bytes`](./Workero-Email.md#val-raw_bytes) copy the whole message into the memory of the program; use [`Workero.Email.raw`](./Workero-Email.md#val-raw) for a large message. The raw message can be read once. The runtime checks the rules for `forward` headers and for the `reply` message.

## Workflow limits

- [Workflows](./workflows.md): workerd has no Workflows engine, so the tests run the class and the binding against a small JavaScript engine. It calls the OCaml class over RPC as Cloudflare's engine does, and it implements steps, retries, `sleep`, `wait_for_event` and replay. The tests do not prove persistence, eviction, real retry timing, the Cloudflare limits or a deployment. Run a Workflow with `wrangler dev` or on Cloudflare before you rely on it.
- Step results, event payloads, params and outputs are [`Workero.Rpc.value`](./Workero-Rpc.md#type-value)s. A number above 1073741823 reads as a ``Float`, not an ``Int` (see [Workflows](./workflows.md)).
- Not wrapped: `retention`, `createBatch` with `count`, `deleteBatch`, `Instance.delete`, `subscribe`, `terminate` and `restart` options, rollback handlers, the rest of the step context (`step`, `config`), a function as `delay`, the cron `schedule` and the `workflowName` of the event. `wait_for_event` returns the payload, not the event.
- A Workflow class and a Durable Object or entrypoint class cannot share a name.

## Entrypoint limits

- [Entrypoints](./entrypoints.md): the `scheduled`, `queue`, `email` and `tail` handlers of a class are not supported.
- The runtime creates a new instance of an entrypoint for each call, so it keeps no state between calls.
- An entrypoint and a Durable Object class cannot share a name.
- A method declared in `~rpc` on a class whose handlers have no `rpc` fails on the first call, not at build time.

## Durable Object limits

- The storage API requires a SQLite-backed class. A class listed in `new_classes` can build, but its key-value and SQL calls fail at runtime. See [Durable Objects](./durable_objects.md).
- RPC methods on a stub: names are declared with `register ~rpc`. Arguments and results are [`Workero.Rpc.t`](./Workero-Rpc.md#type-t). An `Error`, a typed array other than `Uint8Array`, a class instance and a `Symbol` cannot cross the call. A ``Function` argument is released when the call returns. A method name cannot be `fetch`, `alarm`, `connect`, `constructor`, `prototype` or a `webSocket*` handler. See [Durable Objects](./durable_objects.md).
- Stored values are JSON. A `Date` that other code stores reads back as its ISO string and a `Map` as `{}`. A `BigInt` or a cyclic value raises `Invalid_argument`. [`Workero.Durable_object.Storage.put`](./Workero-Durable_object-Storage.md#val-put) raises `Invalid_argument` for a NaN or infinite float.
- The function given to `register` cannot call [`Workero.Promise.await`](./Workero-Promise.md#val-await). Load stored values in `~init`. Keep per-object state in closures.
- [`Workero.Durable_object.register`](./Workero-Durable_object.md#val-register) must run when the module starts. A `register` call that a condition skips is not exported.
- `workero build` needs `workerd`. Set `main` in `wrangler.toml` to the `index.js` that `workero build` writes.
- A `block_concurrency_while` function that raises resets the object.
- SQL: `Int` values are exact only within ±`2^53`; a larger integer can read back as a `Float`. A whole-number `REAL` such as `2.0` reads back as `Int`. `Sql.run` returns only the number of rows written. [`Workero.Durable_object.Storage.transaction_sync`](./Workero-Durable_object-Storage.md#val-transaction_sync) rejects [`Workero.Promise.await`](./Workero-Promise.md#val-await) with `Invalid_argument` and rolls back; use [`Workero.Durable_object.Storage.transaction`](./Workero-Durable_object-Storage.md#val-transaction) to await.
- [WebSockets](./websockets.md): a socket accepted with [`Workero.Websocket.accept`](./Workero-Websocket.md#val-accept) does not hibernate. Do not also call [`Workero.Durable_object.State.accept_websocket`](./Workero-Durable_object-State.md#val-accept_websocket) on that socket. A class without `websocket_message` can accept hibernatable sockets, but does not handle their messages.
- The `workerd` tests cannot prove eviction and re-creation during hibernation, jurisdictions, or the tag and 2048-byte attachment limits. Test these in a deployed Worker.
- [Containers](./durable_objects.md): [`Workero.Durable_object.Container`](./Workero-Durable_object-Container.md) does not wrap `interceptOutboundTcp`, `exec`, `inspect` or the snapshot functions. The tests run `State.container` against `None` in `workerd` and against a JavaScript stub. A separate test, `test/worker-containers`, starts real containers in CI and prints `SKIP containers` where Docker or its images are missing. Raw TCP connect and outbound interception run only there. `workerd` runs containers only with Docker and an egress interceptor image.

## Not supported yet

- The `tail` handler.
- Durable Objects without SQLite storage.
- Vectorize and the Send Email binding.
- `HTMLRewriter`.
- `AbortController` and request cancellation.
- Most of `crypto.subtle`. [`Workero.Crypto`](./Workero-Crypto.md) has digests, HMAC, AES-GCM, PBKDF2 and HKDF with raw keys. It has no key generation, no `exportKey`, no `jwk`, `pkcs8` or `spki` import, no RSA, ECDSA, ECDH, Ed25519, AES-CBC or AES-CTR, no `wrapKey` and no `DigestStream`. Keys are never extractable.

## Differences from native OCaml

- `Sys.word_size` is 32, and `int` has 31 bits.
- There is no file system, except files that you embed. See [Supported libraries](./libraries.md).
- The program has no threads or sub-processes. It can open only outbound TCP connections, with [`Workero.Socket`](./Workero-Socket.md).
Successful compilation does not prove that a library's runtime dependencies are available in a Worker. See [Supported libraries](./libraries.md) and [Testing a worker](./testing.md).


## Report a problem

Open an issue in the [workero repository](https://github.com/ml-in-barcelona/workero). Include the OCaml, wasm\_of\_ocaml and Wrangler versions, and the smallest worker that shows the problem.
