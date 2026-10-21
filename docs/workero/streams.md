
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
[`Workero.Stream.iter`](./Workero-Stream.md#val-iter) calls your function on each chunk. It waits for the next chunk like [`Workero.Promise.await`](./Workero-Promise.md#val-await). The memory use stays small, whatever the size of the body.

For more control, lock the stream with [`Workero.Stream.reader`](./Workero-Stream.md#val-reader). [`Workero.Stream.Reader.read`](./Workero-Stream-Reader.md#val-read) gives `Some chunk`, or `None` at the end. [`Workero.Stream.Reader.cancel`](./Workero-Stream-Reader.md#val-cancel) tells the source to stop. A stream has one reader: a second [`Workero.Stream.reader`](./Workero-Stream.md#val-reader) raises [`Workero.Js_error`](./Workero.md#exception-Js_error).

Read the body only once. [`Workero.Request.text`](./Workero-Request.md#val-text), [`Workero.Request.bytes`](./Workero-Request.md#val-bytes) and [`Workero.Request.body`](./Workero-Request.md#val-body) all use it up. To read it twice, call [`Workero.Request.clone`](./Workero-Request.md#val-clone) first.


## Send a body in steps

[`Workero.Response.stream`](./Workero-Response.md#val-stream) answers at once. Your function runs in its own fiber and writes the body.

```ocaml
let handler _req _env ctx =
  let open Workero in
  Response.stream ctx (fun writer ->
      for i = 1 to 5 do
        Stream.Writer.write writer (Printf.sprintf "chunk %d\n" i);
        Promise.await (sleep 1000)
      done)

let () = Workero.serve handler
```
(`sleep` stands for any function that gives a [`Workero.Promise.t`](./Workero-Promise.md#type-t).)

- The body ends when your function returns.
- If your function raises, the body ends with an error. The error goes to `console.error`.
- `status` and `headers` work as in [`Workero.Response.text`](./Workero-Response.md#val-text).
- The function runs through [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until), so the runtime keeps the Worker alive until it ends. A stream that writes for 60 seconds was tested on Cloudflare.
To send a body and read another one at the same time, use [`Workero.Stream.pipe`](./Workero-Stream.md#val-pipe). It gives a [`Workero.Stream.Writer.t`](./Workero-Stream-Writer.md#type-t) and the [`Workero.Stream.t`](./Workero-Stream.md#type-t) that reads what you write.


## Pass a body through

[`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) sends a stream as the body. Use it with the body of a [`Workero.fetch`](./Workero.md#val-fetch) result. Nothing is copied.

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let upstream = fetch "https://example.com/big-file" in
  match Response.body upstream with
  | Some body -> Response.of_stream ~headers:[ ("x-via", "workero") ] body
  | None -> Response.empty 502

let () = Workero.serve handler
```
To change only the headers or the status of a response, use [`Workero.Response.copy`](./Workero-Response.md#val-copy). See [Requests and responses](./requests.md).

[`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) and [`Workero.Response.copy`](./Workero-Response.md#val-copy) move the body. The original response is used up after the call. To keep it, call [`Workero.Response.clone`](./Workero-Response.md#val-clone) first.


## Back-pressure

[`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) waits until the reader can take more data. A slow client slows your loop. The Worker does not fill its memory with chunks that nobody has read.


## Client disconnect

The Worker gets no event when the client leaves. The next [`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) raises [`Workero.Js_error`](./Workero.md#exception-Js_error). Catch it to clean up.

```ocaml
let handler _req _env ctx =
  let open Workero in
  Response.stream ctx (fun writer ->
      try
        while true do
          Stream.Writer.write writer "tick\n";
          Promise.await (sleep 1000)
        done
      with Js_error _ -> ())

let () = Workero.serve handler
```
A loop that does not write cannot see the disconnect.


## Close and abort

[`Workero.Stream.Writer.close`](./Workero-Stream-Writer.md#val-close) ends the stream. [`Workero.Stream.Writer.abort`](./Workero-Stream-Writer.md#val-abort) ends it with an error, and the client sees a failed body. [`Workero.Response.stream`](./Workero-Response.md#val-stream) closes the writer for you when your function returns, and aborts it when your function raises.
