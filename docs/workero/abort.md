
# Abort and timeouts

[`Workero.Abort_controller`](./Workero-Abort_controller.md) and [`Workero.Abort_signal`](./Workero-Abort_signal.md) wrap `AbortController` and `AbortSignal`. A signal tells running work to stop. Use one to put a timeout on a request or to stop a streaming loop when the client leaves.


## Time out a request

Pass a signal to [`Workero.fetch`](./Workero.md#val-fetch) or [`Workero.Fetcher.fetch`](./Workero-Fetcher.md#val-fetch). [`Workero.Abort_signal.timeout`](./Workero-Abort_signal.md#val-timeout) aborts after a number of milliseconds:

```ocaml
let handler _req _env _ctx =
  let open Workero in
  match fetch ~signal:(Abort_signal.timeout 2000) "https://example.com/slow" with
  | res -> Response.text (Response.body_text res)
  | exception (Js_error _ as exn) when Abort_signal.is_abort exn ->
      Response.text ~status:`Gateway_Timeout "upstream too slow\n"

let () = Workero.serve handler
```
When the signal aborts, the runtime rejects the request. The call raises [`Workero.Js_error`](./Workero.md#exception-Js_error). The reason is a `TimeoutError` for a timeout and an `AbortError` otherwise; [`Workero.Abort_signal.is_abort`](./Workero-Abort_signal.md#val-is_abort) is `true` for both. The signal also cancels the reading of the response body: [`Workero.Response.body_text`](./Workero-Response.md#val-body_text) raises the same way. A signal that has already aborted fails the call without sending a request.


## Abort by hand

[`Workero.Abort_controller.create`](./Workero-Abort_controller.md#val-create) makes a controller, and [`Workero.Abort_controller.signal`](./Workero-Abort_controller.md#val-signal) gives its signal. [`Workero.Abort_controller.abort`](./Workero-Abort_controller.md#val-abort) aborts it, with an optional message that becomes the message of the `AbortError`. [`Workero.Abort_signal.any`](./Workero-Abort_signal.md#val-any) combines signals: it aborts with the first one.

```ocaml
let handler _req _env _ctx =
  let open Workero in
  let stop = Abort_controller.create () in
  let signal =
    Abort_signal.any [ Abort_controller.signal stop; Abort_signal.timeout 2000 ]
  in
  ignore (Timer.set_timeout (fun () -> Abort_controller.abort stop) 500);
  match fetch ~signal "https://example.com/slow" with
  | _ -> Response.text "finished\n"
  | exception (Js_error _ as exn) when Abort_signal.is_abort exn ->
      Response.text "canceled\n"

let () = Workero.serve handler
```

## What an abort cancels

An abort cancels the I/O, not the fiber. The fiber wakes up with an exception when the I/O that it awaits is rejected. Workero cannot stop a fiber that computes or that awaits something else. Two tools help:

- [`Workero.Abort_signal.aborted`](./Workero-Abort_signal.md#val-aborted) and [`Workero.Abort_signal.throw_if_aborted`](./Workero-Abort_signal.md#val-throw_if_aborted) tell a loop to stop between steps.
- [`Workero.Abort_signal.to_promise`](./Workero-Abort_signal.md#val-to_promise) rejects when the signal aborts. Race it against any other promise to stop waiting: `Promise.await (Promise.race [p; Abort_signal.to_promise signal])`. The work behind `p` keeps running; [`Workero.Timer.sleep`](./Workero-Timer.md#val-sleep) cannot be canceled.
[`Workero.Abort_signal.on_abort`](./Workero-Abort_signal.md#val-on_abort) runs a function once, in its own fiber, when the signal aborts. The function may call [`Workero.Promise.await`](./Workero-Promise.md#val-await). An exception that it raises goes to `console.error`.


## Client cancellation

[`Workero.Request.signal`](./Workero-Request.md#val-signal) is the signal of the incoming request. It aborts when the client cancels the request. It needs the `enable_request_signal` compatibility flag in `wrangler.toml`: `compatibility_flags = ["enable_request_signal"]`. The project template sets it. Without the flag, the signal never aborts.

```ocaml
let handler req _env ctx =
  let open Workero in
  let gone = ref false in
  Abort_signal.on_abort (Request.signal req) (fun () -> gone := true);
  Response.stream ctx (fun w ->
      while not !gone do
        Stream.Writer.write w "tick\n";
        ignore (Promise.await (Timer.sleep 1000))
      done)

let () = Workero.serve handler
```
Do not pass `Request.signal` to work that must outlive the client, such as a [`Workero.fetch`](./Workero.md#val-fetch) inside [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until).


### What was verified

In `workerd` 2026-10-19 with `enable_request_signal`, aborting a `fetch` to a Worker that streams its response fires the signal of that Worker's request while the stream is open. With a handler that only awaits a timer, the earlier spike saw no abort event in `workerd serve`. Do not rely on `Request.signal` to detect every client disconnect. Workero has not checked the behavior on Cloudflare production.

[`Workero.Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) raises [`Workero.Js_error`](./Workero.md#exception-Js_error) after a disconnect, with a reason that is not an `AbortError`, so [`Workero.Abort_signal.is_abort`](./Workero-Abort_signal.md#val-is_abort) is `false` for it. Treat any `Js_error` from a write as a disconnect.


## Where signals apply

`?signal` exists on [`Workero.fetch`](./Workero.md#val-fetch), [`Workero.Fetcher.fetch`](./Workero-Fetcher.md#val-fetch) and [`Workero.Fetcher.fetch_request`](./Workero-Fetcher.md#val-fetch_request). [`Workero.Fetcher.fetch_request`](./Workero-Fetcher.md#val-fetch_request) builds a new request with the signal and leaves the signal of the request that you pass unchanged. The new signal replaces the one that the request has; it does not combine them. Use [`Workero.Abort_signal.any`](./Workero-Abort_signal.md#val-any) for that. Bindings such as KV, R2, D1 and Cache take no signal.
