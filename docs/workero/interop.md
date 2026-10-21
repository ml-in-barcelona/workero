
# JavaScript interop

Every workero type that wraps a JavaScript object has two conversions: `of_js` and `to_js`. The types are [`Workero.Request`](./Workero-Request.md), [`Workero.Response`](./Workero-Response.md), [`Workero.Env`](./Workero-Env.md), [`Workero.Context`](./Workero-Context.md), [`Workero.Scheduled`](./Workero-Scheduled.md), [`Workero.Cf`](./Workero-Cf.md) and [`Workero.Promise`](./Workero-Promise.md). They let you call a JavaScript API that workero does not wrap.

[`Workero.js`](./Workero.md#type-js) is the type of a raw JavaScript value. It is `Js_of_ocaml.Js.Unsafe.any`. Use `Js_of_ocaml.Js` to read fields, call methods and convert strings.

```ocaml
open Js_of_ocaml

let global name = Js.Unsafe.get Js.Unsafe.global (Js.string name)

let handler req _env _ctx =
  let raw : Workero.js = Workero.Request.to_js req in
  let method_ : Js.js_string Js.t = Js.Unsafe.get raw (Js.string "method") in
  let done_ : Js.js_string Js.t Workero.Promise.t =
    Workero.Promise.of_js
      (Js.Unsafe.meth_call (global "Promise") "resolve"
         [| Js.Unsafe.inject (Js.string "done") |])
  in
  let word = Js.to_string (Workero.Promise.await done_) in
  Workero.Response.text (Js.to_string method_ ^ " " ^ word ^ "\n")

let () = Workero.serve handler
```
For a Promise, [`Workero.Promise.of_js`](./Workero-Promise.md#val-of_js) needs you to state the type of the resolved value. A JavaScript string is a `Js.js_string Js.t`, not a `string`. Convert it with `Js.to_string`. A wrong type is not caught by the compiler.

Add `js_of_ocaml` to `libraries` next to `workero`.
