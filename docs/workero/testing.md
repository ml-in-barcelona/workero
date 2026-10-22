
# Testing a worker

Test your worker with `workerd test` to run the compiled WebAssembly in the Workers runtime. This checks the routes and bindings in your test setup without deploying the worker. See [Limits](./limits.md) for Cloudflare platform limits.


## Run a worker test

1. Install `workerd` on `PATH`. The repository CI uses `npm install -g workerd`.
2. Build the worker: `workero build src/main.bc.wasm.js --out _worker-test`.
3. Write a `workerd` config. List the files of `_worker-test` as modules (`.js` as `esModule`, `.wasm` as `wasm`). Bind the worker to a test worker as a service.
4. In the test worker, call the service with `env.WORKER.fetch(url)` and compare the status, headers, and body. Call `env.WORKER.scheduled({ cron, scheduledTime })` to test the cron handler. To invoke the queue handler with `env.WORKER.queue(name, messages)`, enable `service_binding_extra_handlers` on the test worker and run `workerd test --experimental config.capnp`.
5. Run `workerd test config.capnp` for fetch and scheduled tests.
`workerd` cannot run the email handler this way. See [Email](./email.md).

`test/worker/run.sh` shows a working config generator. It builds `test/worker/main.ml`, then runs the suites imported by `test/worker/tests.mjs`. Worker routes live in `test/worker/routes_*.ml`; cases live in `test/worker/cases/*.mjs`. Queue cases use a separate `test/worker/tests_queue.mjs` test service with `--experimental`. Set `globalOutbound` to a test worker to answer [`Workero.fetch`](./Workero.md#val-fetch) calls without the network. The repository tests exercise compiled Wasm, JSPI waits, and the `workerd` runtime. They use JS test services for KV, R2, and Cache. D1 uses a wrapped adapter backed by Durable Object SQLite. These substitutes test workero calls against the adapter interfaces. They do not test production Cloudflare storage services. The repository also tests startup failure in `test/worker-init/`, handler exports in `test/worker-exports/` and build/package behavior in `test/cli/`.

The Durable Object suite in `test/worker/cases/do.mjs` tests synchronous SQLite queries and writes, transaction commit and rollback (including an attempt to call `Promise.await`), hibernatable WebSocket message and close callbacks, attachments, tags, broadcast and automatic responses. These `workerd` tests do not evict an object between WebSocket events, so they do not prove recovery after hibernation. They also do not test `websocket_error` or a suspension inside a WebSocket event callback. Test eviction and platform limits in a deployed Worker.

An exception that escapes a handler fails a service-binding call. An HTTP request gets status 500 instead.


## Test code without the worker runtime

For code that does not wait, such as parsing with [`Workero.URL`](./Workero-URL.md), use the Alcotest unit tests in `test/unit/`. They compile with `(modes js)` and run in Node via `dune test`. They do not exercise compiled Wasm or the worker runtime. Node's JSPI support depends on the version. Use `workerd test` for worker code that calls [`Workero.Promise.await`](./Workero-Promise.md#val-await).
