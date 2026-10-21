
# Waiting for JavaScript

JavaScript APIs return Promises. In workero you do not chain them. You write direct style code, and a call waits for the result.

```ocaml
open Js_of_ocaml

let sleep ms =
  Workero.Promise.make (fun ~resolve ~reject:_ ->
      let wake () = resolve () in
      ignore
        (Js.Unsafe.fun_call
           (Js.Unsafe.get Js.Unsafe.global (Js.string "setTimeout"))
           [| Js.Unsafe.inject (Js.wrap_callback wake); Js.Unsafe.inject ms |]))

let handler _req _env ctx =
  let open Workero in
  Context.wait_until ctx (fun () ->
      Promise.await (sleep 100);
      print_endline "background work done");
  let a = sleep 100 and b = sleep 100 in
  Promise.await a;
  Promise.await b;
  let failed = Promise.reject (Promise.error_of_string "boom") in
  match Promise.await failed with
  | () -> Response.text "unreachable\n"
  | exception Js_error reason ->
      Response.text ("rejected: " ^ Promise.error_to_string reason ^ "\n")

let () = Workero.serve handler
```

## How it works

Every handler runs in a fiber. [`Workero.Promise.await`](./Workero-Promise.md#val-await) suspends the fiber until the Promise settles. Meanwhile the worker runs other requests. The body readers ([`Workero.Request.body_text`](./Workero-Request.md#val-body_text), [`Workero.Response.body_text`](./Workero-Response.md#val-body_text)) and [`Workero.fetch`](./Workero.md#val-fetch) wait in the same way.

This is the JavaScript Promise Integration (JSPI) of WebAssembly with OCaml 5 effects. wasm\_of\_ocaml enables it by default.

To run two things at once, start both Promises before you wait for either. Waiting for each in turn takes the sum of the times. Waiting after both started takes the longest one.


## Promise

[`Workero.Promise.t`](./Workero-Promise.md#type-t) is the JavaScript `Promise`.

- [`Workero.Promise.make`](./Workero-Promise.md#val-make) is `new Promise(executor)`. The executor gets `resolve` and `reject`. `reject` takes a [`Workero.Promise.error`](./Workero-Promise.md#type-error).
- [`Workero.Promise.resolve`](./Workero-Promise.md#val-resolve) and [`Workero.Promise.reject`](./Workero-Promise.md#val-reject) are `Promise.resolve` and `Promise.reject`.
- [`Workero.Promise.await`](./Workero-Promise.md#val-await) gives the resolved value.
- [`Workero.Promise.of_js`](./Workero-Promise.md#val-of_js) and [`Workero.Promise.to_js`](./Workero-Promise.md#val-to_js) convert from and to a raw JavaScript Promise. See [JavaScript interop](./interop.md).
`Promise.t` is backed by `Js_of_ocaml.Promise`. A promise resolved with another promise is boxed, so `'a t t` is a promise of a promise, which a raw JavaScript Promise would flatten.


## Combinators

- [`Workero.Promise.map`](./Workero-Promise.md#val-map) and [`Workero.Promise.bind`](./Workero-Promise.md#val-bind) transform the resolved value, like `then`.
- [`Workero.Promise.all`](./Workero-Promise.md#val-all) resolves with every value in order, or rejects with the first rejection.
- [`Workero.Promise.race`](./Workero-Promise.md#val-race) settles like the first promise to settle.
- [`Workero.Promise.any`](./Workero-Promise.md#val-any) resolves with the first value. When all reject, it rejects with an `AggregateError`.
- [`Workero.Promise.all_settled`](./Workero-Promise.md#val-all_settled) resolves when every promise has settled, with a `result` for each. It never rejects.
```ocaml
let handler _req _env _ctx =
  let open Workero in
  let numbers = Promise.all [ Promise.resolve 1; Promise.resolve 2 ] in
  let total = Promise.map (List.fold_left ( + ) 0) numbers in
  let settled =
    Promise.all_settled
      [ Promise.resolve "ok"; Promise.reject (Promise.error_of_string "no") ]
  in
  let describe = function
    | Ok value -> value
    | Error reason -> Promise.error_to_string reason
  in
  let results = List.map describe (Promise.await settled) in
  Response.text
    (Printf.sprintf "total=%d results=%s\n" (Promise.await total)
       (String.concat "," results))

let () = Workero.serve handler
```
You do not need them to wait for several things. Starting both Promises, then awaiting each, runs them at once.


## Errors

[`Workero.Promise.await`](./Workero-Promise.md#val-await) raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when a JavaScript Promise rejects. A rejection that comes from OCaml code, such as an exception in a `map` or `bind` function, in a `make` executor or in a decoder, is different: `await` re-raises the original OCaml exception. [`Workero.Promise.error_of_exn`](./Workero-Promise.md#val-error_of_exn) makes such a rejection.

For [`Workero.Js_error`](./Workero.md#exception-Js_error), the payload is a [`Workero.Promise.error`](./Workero-Promise.md#type-error): the original rejection reason, which JavaScript allows to be any value, so the type is opaque.

- [`Workero.Promise.error_to_string`](./Workero-Promise.md#val-error_to_string) shows it as the JavaScript `String` function does, for example `"Error: nope"`.
- [`Workero.Promise.error_of_string`](./Workero-Promise.md#val-error_of_string) makes a JavaScript `Error` with a message.
- [`Workero.Promise.error_to_js`](./Workero-Promise.md#val-error_to_js) and [`Workero.Promise.error_of_js`](./Workero-Promise.md#val-error_of_js) give and take the raw value, so a handler can inspect or re-raise it.
Catch it with `match ... with exception Js_error reason -> ...`. An exception that you do not catch is an error of the handler (see [Handlers](./handlers.md)).

An exception that escapes the top level of the program, during start-up, fails the load of the Worker. The error is `workero: OCaml initialisation failed (exit code N): ...` followed by the OCaml exception text. Fix the exception and rebuild.


## Work after the response

[`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until) runs a function in its own fiber and keeps the worker alive until it returns, after the response is sent. The function can call [`Workero.Promise.await`](./Workero-Promise.md#val-await). If it raises, the runtime logs the error. The request that called it and other requests are not affected.


## What you cannot do

Await only inside a handler given to [`Workero.serve`](./Workero.md#val-serve) or [`Workero.scheduled`](./Workero.md#val-scheduled), inside a function given to [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until), or in code that these call. Anywhere else the wait fails. Observed failures:

- In a callback that JavaScript calls, such as a `setTimeout` function: the callback runs outside any handler fiber, and the wait raises `Stdlib.Effect.Unhandled(Workero__Async.Await(_))`.
- In the executor of [`Workero.Promise.make`](./Workero-Promise.md#val-make): the wait fails with `SuspendError: trying to suspend JS frames`.
- At the top level of the program: the load of the Worker fails with `workero: OCaml initialisation failed (exit code 2)` and the same `Effect.Unhandled` message.
To use the result of a callback, resolve a [`Workero.Promise.t`](./Workero-Promise.md#type-t) from it and await that Promise in the handler, as the sample does with `sleep`.
