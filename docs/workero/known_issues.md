
# Support and known issues

Behavior that differs from JavaScript Workers and native OCaml, and features not supported yet.


## Differences from JavaScript Workers

- A handler waits only through [`Workero.Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await), [`Workero.fetch`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-fetch) and the body readers. A function that JavaScript calls, such as a `setTimeout` callback, cannot wait. See [Async and background work](./async.md).
- [`Workero.URL`](./Workero-URL.md) uses the WHATWG `URL`, but [`Workero.URL.path`](https://ml-in-barcelona.github.io/workero/workero/Workero/URL/index.html#val-path) is decoded and only `http` and `https` URLs parse. See [URLs](./url.md).
- A response cannot have a status below 200 or above 599\. The runtime rejects them, so [`Workero.Status`](./Workero-Status.md) has ``Continue` and ``Switching_Protocols` only to read codes; use [`Workero.Websocket`](./Workero-Websocket.md) for 101\.

## Limits of streams, forms and WebSockets

- A client disconnect shows only as a failed [`Workero.Stream.Writer.write`](https://ml-in-barcelona.github.io/workero/workero/Workero/Stream/Writer/index.html#val-write).
- [`Workero.Response.copy`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-copy) and [`Workero.Response.of_stream`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-of_stream) share the original body stream. It can be consumed only once. Call [`Workero.Response.clone`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-clone) before reading if you need two copies.
- [`Workero.Request.form_data`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-form_data) holds the whole upload in memory. See [Forms](./forms.md).

## Differences from native OCaml

- `Sys.word_size` is 32, and `int` has 31 bits.
- There is no file system, except files that you embed. See [Supported libraries](./libraries.md).
- The program has no threads, sockets or sub-processes.
Successful compilation does not prove that a library's runtime dependencies are available in a Worker. See [Supported libraries](./libraries.md) and [Testing a worker](./testing.md).


## Report a problem

Open an issue in the [workero repository](https://github.com/ml-in-barcelona/workero). Include the OCaml, wasm\_of\_ocaml and Wrangler versions, and the smallest worker that shows the problem.
