
# Streams

A [`Workero.Stream.t`](./Workero-Stream.md#type-t) is a JavaScript `ReadableStream` of bytes. Use it to read a large body in chunks, to send a body that you build in steps, and to pass a body from one server to another without a copy.


## Read a request body in chunks

[`Workero.Request.body`](./Workero-Request.md#val-body) gives the body as a stream. It is `None` when the request has no body, for example for `GET`.

```ocaml
let handler req _env _ctx =
  let open Workero in
  let total = ref 0 in
  Option.iter
    (Stream.iter (fun chunk -> total := !total + String.length chunk))
    (Request.body req);
  Response.text (Printf.sprintf "%d bytes\n" !total)

let () = Workero.serve handler
```
[`Workero.Stream.iter`](./Workero-Stream.md#val-iter) calls your function on each chunk. It waits for the next chunk like [`Workero.Promise.await`](./Workero-Promise.md#val-await). Process chunks as they arrive instead of collecting the whole body in memory.

For more control, lock the stream with [`Workero.Stream.reader`](./Workero-Stream.md#val-reader). [`Workero.Stream.Reader.read`](./Workero-Stream-Reader.md#val-read) gives `Some chunk`, or `None` at the end. [`Workero.Stream.Reader.cancel`](./Workero-Stream-Reader.md#val-cancel) tells the source to stop. A stream has one reader: a second [`Workero.Stream.reader`](./Workero-Stream.md#val-reader) raises [`Workero.Js_error`](./Workero.md#exception-Js_error).

Getting a handle with [`Workero.Request.body`](./Workero-Request.md#val-body) does not read or lock the body. The body is consumed when you read its stream or call a body reader such as [`Workero.Request.text`](./Workero-Request.md#val-text), [`Workero.Request.bytes`](./Workero-Request.md#val-bytes) or [`Workero.Request.form_data`](./Workero-Request.md#val-form_data). Do not use two readers on the same body. To read it twice, call [`Workero.Request.clone`](./Workero-Request.md#val-clone) before consuming either copy.


## Send a body in steps

[`Workero.Response.stream`](./Workero-Response.md#val-stream) returns a response with a streaming body. Your function starts immediately in its own fiber and writes the body. Synchronous work before its first suspension can delay the response.

```ocaml
let handler _req _env ctx =
  let open Workero in
  Response.stream ctx (fun writer ->
      for i = 1 to 5 do
        Stream.Writer.write writer (Printf.sprintf "chunk %d\n" i);
        Promise.await (Timer.sleep 1000)
      done)

let () = Workero.serve handler
```
- The body ends when your function returns.
- If your function raises, the body ends with an error. The error goes to `console.error`.
- `status` and `headers` work as in [`Workero.Response.text`](./Workero-Response.md#val-text).
- The function runs through [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until). While the client remains connected and receives the stream, the HTTP invocation stays active. After the response ends or the client disconnects, remaining `waitUntil` work has a shared limit of 30 seconds. See [Async and background work](./async.md).
To send a body and read another one at the same time, use [`Workero.Stream.pipe`](./Workero-Stream.md#val-pipe). It gives a [`Workero.Stream.Writer.t`](./Workero-Stream-Writer.md#type-t) and the [`Workero.Stream.t`](./Workero-Stream.md#type-t) that reads what you write.


## Pass a body through

[`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) sends a stream as the body without buffering it. It creates a new response with status 200 and the headers you pass. If you want to forward an upstream response without changing its status or headers, use [`Workero.Response.copy`](./Workero-Response.md#val-copy) instead:

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let upstream = fetch "https://example.com/big-file" in
  Response.copy upstream

let () = Workero.serve handler
```
To change only headers or status, pass `~headers` or `~status` to [`Workero.Response.copy`](./Workero-Response.md#val-copy). It preserves the upstream status and headers when you omit those arguments. If you already have a [`Workero.Stream.t`](./Workero-Stream.md#type-t), use [`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) with the intended status and headers. See [Requests and responses](./requests.md).

[`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) and [`Workero.Response.copy`](./Workero-Response.md#val-copy) pass the existing body stream to the new response; they do not read it when they get the handle. The original and new responses then share a body that cannot be consumed twice. Call [`Workero.Response.clone`](./Workero-Response.md#val-clone) before either copy consumes the body if you need to read both. To read both, call [`Workero.Response.clone`](./Workero-Response.md#val-clone) before consuming either body.


## Back-pressure

[`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) waits until the reader can take more data. A slow client slows your loop. The Worker does not fill its memory with chunks that nobody has read.


## Client disconnect

The Worker gets no disconnect event when the client leaves. A later [`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) can raise [`Workero.Js_error`](./Workero.md#exception-Js_error). Catch it to clean up.

```ocaml
let handler _req _env ctx =
  let open Workero in
  Response.stream ctx (fun writer ->
      try
        while true do
          Stream.Writer.write writer "tick\n";
          Promise.await (Timer.sleep 1000)
        done
      with Js_error _ -> ())

let () = Workero.serve handler
```
A loop that does not write cannot see the disconnect.


## Close and abort

[`Workero.Stream.Writer.close`](./Workero-Stream-Writer.md#val-close) ends the stream. [`Workero.Stream.Writer.abort`](./Workero-Stream-Writer.md#val-abort) ends it with an error, and the client sees a failed body. [`Workero.Response.stream`](./Workero-Response.md#val-stream) closes the writer for you when your function returns, and aborts it when your function raises.
