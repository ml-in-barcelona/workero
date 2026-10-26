
# Module `Workero.Abort_signal`

`AbortSignal`: tells running work to stop.

An abort cancels the I/O, not the fiber. A function that starts cancelable I/O takes a `?signal`, such as [`Workero.fetch`](./Workero.md#val-fetch). When the signal aborts, the runtime rejects the I/O, and the call that awaits it raises [`Workero.Js_error`](./Workero.md#exception-Js_error). Use [`is_abort`](./#val-is_abort) to tell that error from others. An abort cannot interrupt OCaml code that computes or awaits something else: test [`aborted`](./#val-aborted) between steps, or race the await against [`to_promise`](./#val-to_promise).

```ocaml
type t
```
```ocaml
val aborted : t -> bool
```
```ocaml
val reason : t -> Promise.error option
```
The abort reason; `None` while the signal has not aborted. JavaScript allows any value, so the type is [`Promise.error`](./Workero-Promise.md#type-error).

```ocaml
val throw_if_aborted : t -> unit
```
Raises [`Workero.Js_error`](./Workero.md#exception-Js_error) with the reason when the signal has aborted, like `signal.throwIfAborted()`.

```ocaml
val timeout : int -> t
```
`timeout ms` is `AbortSignal.timeout ms`. It aborts after `ms` milliseconds with a `TimeoutError`. The timer starts at once, so call it only from inside a handler or a [`Context.wait_until`](./Workero-Context.md#val-wait_until) function.

```ocaml
val any : t list -> t
```
`AbortSignal.any`: aborts when the first of the signals aborts, with the reason of that signal.

```ocaml
val aborted_now : 
  ?reason:[ `Abort of string | `Timeout of string ] ->
  unit ->
  t
```
`AbortSignal.abort()`: a signal that has already aborted. ``Abort msg` gives an `AbortError` and ``Timeout msg` a `TimeoutError` with that message. Without it the reason is the default `AbortError`.

```ocaml
val on_abort : t -> (unit -> unit) -> unit
```
`on_abort s f` runs `f` once, in its own fiber, when `s` aborts, or at once when `s` has already aborted. `f` may call [`Promise.await`](./Workero-Promise.md#val-await). An exception that `f` raises is written to `console.error`.

```ocaml
val to_promise : t -> 'a Promise.t
```
A promise that never resolves and rejects with the reason when the signal aborts. Use it in [`Promise.race`](./Workero-Promise.md#val-race) to stop waiting for any promise: `Promise.race [p; Abort_signal.to_promise s]`. The work behind `p` keeps running.

```ocaml
val is_abort : exn -> bool
```
`true` for a [`Workero.Js_error`](./Workero.md#exception-Js_error) whose reason is a JavaScript `Error` named `AbortError` or `TimeoutError`. A `Js_error` with another reason, such as the one from [`Stream.Writer.write`](./Workero-Stream-Writer.md#val-write) after a client disconnect, gives `false`.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```