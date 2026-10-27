
# Tail Workers

A [Tail Worker](https://developers.cloudflare.com/workers/observability/logs/tail-workers/) receives a record of each invocation of another Worker, the producer: its event, its console output, its exceptions and its outcome. Register [`Workero.tail`](./Workero.md#val-tail) to write one. It gets a list of [`Workero.Trace.t`](./Workero-Trace.md#type-t) values.


## Configure

A tail Worker is a separate Worker. Build it as its own program, with its own `wrangler.toml` and no routes. Do not list a Worker as its own tail consumer. The producer names the tail Worker:

```toml
name = "my-app"
main = "_worker/index.js"

[[tail_consumers]]
service = "my-tail"
```
The tail Worker has its own `name`:

```toml
name = "my-tail"
main = "_worker/index.js"
compatibility_date = "2026-10-01"

[build]
command = "workero build src/main.bc.wasm.js"
```
The tail Worker must register [`Workero.tail`](./Workero.md#val-tail). A Worker without a `tail` export that a producer lists as a consumer makes `workerd` log `Handler does not export a tail() function` at the first event. The producer is not affected.


## Handle trace items

This tail Worker logs the exceptions of the producer:

```ocaml
let () =
  Workero.tail (fun traces _env _ctx ->
      List.iter
        (fun trace ->
          List.iter
            (fun (e : Workero.Trace.exn_info) ->
              Workero.Console.error (e.name ^ ": " ^ e.message))
            (Workero.Trace.exceptions trace))
        traces)
```
The runtime calls the handler after the producer invocation ends, and for the sub-requests that the producer makes through service bindings. A fetch item arrives after the response body has been read or the response has been canceled. The handler runs in a fiber, so it can call [`Workero.fetch`](./Workero.md#val-fetch), a binding and [`Workero.Promise.await`](./Workero-Promise.md#val-await). Use [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until) for work that must finish after the handler returns. An exception in the handler is not reported to the producer: log inside the handler.


## Read a trace item

- [`Workero.Trace.outcome`](./Workero-Trace.md#type-outcome) is `Ok`, `Exception`, `Canceled` (often a client that disconnected) or another [`Workero.Trace.outcome`](./Workero-Trace.md#type-outcome).
- [`Workero.Trace.event`](./Workero-Trace.md#type-event) is `Fetch` with its [`Workero.Trace.Request.t`](./Workero-Trace-Request.md#type-t) and response status, `Scheduled`, `Queue`, `Alarm`, `Email`, `Rpc`, `Tail`, `Hibernatable_websocket`, `Custom`, or `Other` with the raw value for any other event.
- [`Workero.Trace.logs`](./Workero-Trace.md#val-logs) lists each console call with its level and its arguments as `Jsonkit.t` values. The runtime serializes the arguments before it gives them to the tail Worker, so `undefined` reads as ``Null`, a `BigInt` as a string and a function as its source text.
- [`Workero.Trace.exceptions`](./Workero-Trace.md#val-exceptions) lists the uncaught exceptions.
- [`Workero.Trace.script_name`](./Workero-Trace.md#val-script_name), [`Workero.Trace.event_timestamp`](./Workero-Trace.md#val-event_timestamp), [`Workero.Trace.truncated`](./Workero-Trace.md#val-truncated), [`Workero.Trace.wall_time`](./Workero-Trace.md#val-wall_time) and [`Workero.Trace.cpu_time`](./Workero-Trace.md#val-cpu_time) give the rest.
The URL and headers of a request are redacted by default. [`Workero.Trace.Request.unredacted`](./Workero-Trace-Request.md#val-unredacted) gives the raw values. A field that has no accessor, such as `scriptVersion`, is read from [`Workero.Trace.to_js`](./Workero-Trace.md#val-to_js) with [`Workero.Decode`](./Workero-Decode.md).


## Stream events

A streaming tail Worker gets each event of an invocation as it happens, not after it ends. Register [`Workero.tail_stream`](./Workero.md#val-tail_stream). The runtime calls it once per invocation with the onset, and the function that it returns gets the later events, up to the outcome.

The producer lists the Worker in `streamingTails` in a `workerd` config.

```ocaml
let () =
  Workero.tail_stream (fun onset _env _ctx ->
      (match Workero.Trace.Stream.kind onset with
      | Onset { info = Fetch { url; _ }; _ } -> Workero.Console.log url
      | _ -> ());
      fun event ->
        match Workero.Trace.Stream.kind event with
        | Exception { name; message; _ } ->
            Workero.Console.error (name ^ ": " ^ message)
        | _ -> ())
```
[`Workero.Trace.Stream.kind`](./Workero-Trace-Stream.md#val-kind) is [`Workero.Trace.Stream.kind`](./Workero-Trace-Stream.md#type-kind): `Onset`, `Log`, `Exception`, `Return`, `Outcome`, `Span_open`, `Span_close`, `Diagnostic_channel`, `Attributes` or `Other`. Events of one invocation share [`Workero.Trace.Stream.invocation_id`](./Workero-Trace-Stream.md#val-invocation_id) and arrive with a growing [`Workero.Trace.Stream.sequence`](./Workero-Trace-Stream.md#val-sequence).


## Limits

The tests run the streaming tail only in `workerd`. The Cloudflare documentation was not checked for it.

In local `workerd`, [`Workero.Trace.wall_time`](./Workero-Trace.md#val-wall_time) and [`Workero.Trace.cpu_time`](./Workero-Trace.md#val-cpu_time) are `0.` and [`Workero.Trace.script_name`](./Workero-Trace.md#val-script_name) is `None`. The tests cannot produce an email or a custom event, so [`Workero.Trace.event.Email`](./Workero-Trace.md#type-event.Email) and [`Workero.Trace.event.Custom`](./Workero-Trace.md#type-event.Custom) have no test.
