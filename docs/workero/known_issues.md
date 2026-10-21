
# Support and known issues

What does not work yet, and what behaves differently from what you may expect.


## Differences from JavaScript Workers

- A handler waits only through [`Workero.Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch) and the body readers. A function that JavaScript calls, such as a `setTimeout` callback, cannot wait. See [Waiting for JavaScript](./async.md).
- [`Workero.URL`](./Workero-URL.md) uses the WHATWG `URL`, but [`Workero.URL.path`](./Workero-URL.md#val-path) is decoded and only `http` and `https` URLs parse. See [Requests and responses](./requests.md).
- A response cannot have a status below 200 or above 599\. The runtime rejects them, so [`Workero.Status`](./Workero-Status.md) has ``Continue` and ``Switching_Protocols` only to read codes; use [`Workero.Websocket`](./Workero-Websocket.md) for 101\.

## Limits of streams, forms and WebSockets

- A client disconnect shows only as a failed [`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write).
- [`Workero.Response.copy`](./Workero-Response.md#val-copy) and [`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) use up the original body. Call [`Workero.Response.clone`](./Workero-Response.md#val-clone) first to keep it.
- [`Workero.Request.form_data`](./Workero-Request.md#val-form_data) holds the whole upload in memory. See [Forms](./forms.md).

## Differences from native OCaml

- `Sys.word_size` is 32, and `int` has 31 bits.
- There is no file system, except files that you embed. See [Supported libraries](./libraries.md).
- The program has no threads, sockets or sub-processes.

## Report a problem

Open an issue in the [workero repository](https://github.com/ml-in-barcelona/workero). Include the OCaml, wasm\_of\_ocaml and Wrangler versions, and the smallest worker that shows the problem.
