
# Runtime APIs

Workero provides OCaml interfaces to APIs in the Cloudflare Workers runtime. Use them to read requests, return responses, make HTTP requests, and manage background work. For configured resources such as KV, R2, and D1, see [Bindings](./bindings.md).


## HTTP

- [Handlers](./handlers.md): register HTTP and scheduled handlers with [`Workero.serve`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-serve) and [`Workero.scheduled`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-scheduled).
- [Requests and responses](./requests.md): methods, headers, status codes, request metadata, and body ownership.
- [Fetch](./fetch.md): make outgoing HTTP requests with a string body.
- [URLs](./url.md): read encoded and decoded paths and query parameters.
- [JSON](./json.md): parse, decode, and return JSON with jsonkit.
- [Streams](./streams.md): read and write bodies in chunks or forward a body.
- [Forms and file uploads](./forms.md): read multipart and URL-encoded forms.
- [WebSockets](./websockets.md): accept connections and receive messages.

## Execution

- [Async and background work](./async.md): wait for results, run concurrent operations, and use [`Workero.Context.wait_until`](https://ml-in-barcelona.github.io/workero/workero/Workero/Context/index.html#val-wait_until).
- [Console and logging](./logging.md): write log entries or use OCaml standard output.
- [Timers, time, and randomness](./globals.md): delays, timestamps, random bytes, and UUIDs.

## Cache

The [Cache API](./cache.md) reads and writes cached responses in the data center that runs your Worker. It uses `caches.default` and needs no `env` binding.


## API coverage

Each guide describes the operations that Workero exposes. The [Cloudflare runtime API reference](https://developers.cloudflare.com/workers/runtime-apis/) describes the wider platform. Use [JavaScript interop](./interop.md) when you need an available runtime operation without a typed Workero wrapper.

See [`Workero`](./Workero.md) for OCaml signatures and [Runtime limits](./limits.md) for the conditions that apply to your Worker.
