
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
  match Promise.await (Promise.reject "boom") with
  | () -> Response.text "unreachable\n"
  | exception Js_error message -> Response.text ("rejected: " ^ message ^ "\n")

let () = Workero.serve handler
```

## How it works

Every handler runs in a fiber. [`Workero.Promise.await`](./Workero-Promise.md#val-await) suspends the fiber until the Promise settles. Meanwhile the worker runs other requests. The body readers ([`Workero.Request.text`](./Workero-Request.md#val-text), [`Workero.Response.body_text`](./Workero-Response.md#val-body_text)) and [`Workero.fetch`](./Workero.md#val-fetch) wait in the same way.

This is the JavaScript Promise Integration (JSPI) of WebAssembly with OCaml 5 effects. wasm\_of\_ocaml enables it by default.

To run two things at once, start both Promises before you wait for either. Waiting for each in turn takes the sum of the times. Waiting after both started takes the longest one.


## Promise

[`Workero.Promise.t`](./Workero-Promise.md#type-t) is the JavaScript `Promise`.

- [`Workero.Promise.make`](./Workero-Promise.md#val-make) is `new Promise(executor)`. The executor gets `resolve` and `reject`. `reject msg` rejects with a JavaScript `Error` whose message is `msg`.
- [`Workero.Promise.resolve`](./Workero-Promise.md#val-resolve) and [`Workero.Promise.reject`](./Workero-Promise.md#val-reject) are `Promise.resolve` and `Promise.reject`.
- [`Workero.Promise.await`](./Workero-Promise.md#val-await) gives the resolved value.
- [`Workero.Promise.of_js`](./Workero-Promise.md#val-of_js) and [`Workero.Promise.to_js`](./Workero-Promise.md#val-to_js) convert from and to a raw JavaScript Promise. See [JavaScript interop](./interop.md).

## Errors

[`Workero.Promise.await`](./Workero-Promise.md#val-await) raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when the Promise rejects. The payload is the rejection reason converted with the JavaScript `String` function. Catch it with `match ... with exception Js_error message -> ...`. An exception that you do not catch is an error of the handler (see [Handlers](./handlers.md)).

An exception that escapes the top level of the program, during start-up, fails the load of the Worker. The error is `OCaml initialisation failed (exit code N): ...` followed by the OCaml exception text. Fix the exception and rebuild.


## Work after the response

[`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until) runs a function in its own fiber and keeps the worker alive until it returns, after the response is sent. The function can call [`Workero.Promise.await`](./Workero-Promise.md#val-await). If it raises, the runtime logs the error. The request that called it and other requests are not affected.


## What you cannot do

[`Workero.Promise.await`](./Workero-Promise.md#val-await) works only in a handler, in a function given to [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until), or in code that these call. It does not work in a callback that JavaScript calls, such as a `setTimeout` function. That code runs outside the fiber, and a wait there fails with a `SuspendError`. To use the result of a callback, resolve a [`Workero.Promise.t`](./Workero-Promise.md#type-t) from it and await that Promise in the handler, as the sample does with `sleep`.

Do not wait at the top level of the program either.
