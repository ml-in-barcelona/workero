
# Support and known issues

Behavior that differs from JavaScript Workers and native OCaml, and features not supported yet.


## Differences from JavaScript Workers

- A handler waits only through [`Workero.Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch) and the body readers. A function that JavaScript calls, such as a `setTimeout` callback, cannot wait. See [Waiting for JavaScript](./async.md).
- [`Workero.URL`](./Workero-URL.md) is not the WHATWG `URL`. See [Requests and responses](./requests.md).
- [`Workero.Response.redirect`](./Workero-Response.md#val-redirect) needs an absolute URL.
- A status that allows no body (101, 204, 205, 304\) needs an empty body.
- Request and response bodies are whole strings. There is no streaming.
- [`Workero.Request.url`](./Workero-Request.md#val-url) raises `Invalid_argument` for a host with `"_"` and for a URL with userinfo.

## Differences from native OCaml

- `Sys.word_size` is 32, and `int` has 31 bits.
- There is no file system, except files that you embed. See [Supported libraries](./libraries.md).
- Output must be flushed to reach the logs. See [Logging](./logging.md).
- The program has no threads, sockets or sub-processes.

## Not supported yet

- Streaming bodies.
- `passThroughOnException`.
- The `start` and `queue` events.

## Report a problem

Open an issue in the [workero repository](https://github.com/ml-in-barcelona/workero). Include the OCaml, wasm\_of\_ocaml and Wrangler versions, and the smallest worker that shows the problem.
