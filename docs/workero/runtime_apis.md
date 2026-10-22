
# Runtime APIs

Workero provides OCaml interfaces to APIs in the Cloudflare Workers runtime, with helpers for routing and JSON. For configuration and resources accessed through `env`, see [Bindings](./bindings.md).


## Handlers and routing

- [Handlers](./handlers.md): register HTTP, scheduled, and queue handlers with [`Workero.serve`](./Workero.md#val-serve), [`Workero.scheduled`](./Workero.md#val-scheduled), and [`Workero.queue`](./Workero.md#val-queue).
- [Router](./router.md): match methods and paths, read route parameters, and mount groups of routes.

## HTTP and data

- [Requests and responses](./requests.md): read headers and bodies, choose a status, and return a response.
- [Fetch](./fetch.md): make outgoing HTTP requests.
- [URLs](./url.md): read encoded and decoded paths and query parameters.
- [JSON](./json.md): parse and decode bodies, return JSON, and convert values for JavaScript APIs.
- [Streams](./streams.md): read and write bodies in chunks or forward a body.
- [Forms and file uploads](./forms.md): read multipart and URL-encoded forms.
- [WebSockets](./websockets.md): accept connections and receive messages. For hibernating connections, see [Durable Objects](./durable_objects.md).
- [Cache](./cache.md): read and write cached responses in the local data center. Cache uses `caches.default` and needs no `env` binding.

## Execution

- [Async and background work](./async.md): wait for results, run independent operations, and use [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until).
- [Logging](./logging.md): write console entries or use OCaml standard output.
- [Timers, time, and randomness](./globals.md): delays, timestamps, random bytes, and UUIDs.

## Reference

See [`Workero`](./Workero.md) for OCaml signatures. Each guide describes the operations Workero exposes and links to the corresponding platform documentation. The [Cloudflare runtime API reference](https://developers.cloudflare.com/workers/runtime-apis/) describes the wider platform. Use [JavaScript interop](./interop.md) for available operations without a typed wrapper.
