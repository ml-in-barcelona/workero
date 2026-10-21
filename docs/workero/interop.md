
# JavaScript interop

Every workero type that wraps a JavaScript object has two conversions: `of_js` and `to_js`. The types are [`Workero.Request`](./Workero-Request.md), [`Workero.Response`](./Workero-Response.md), [`Workero.Env`](./Workero-Env.md), [`Workero.Context`](./Workero-Context.md), [`Workero.Scheduled`](./Workero-Scheduled.md), [`Workero.Cf`](./Workero-Cf.md), [`Workero.KV`](./Workero-KV.md), [`Workero.R2`](./Workero-R2.md), [`Workero.D1`](./Workero-D1.md) and [`Workero.Promise`](./Workero-Promise.md). They let you call a JavaScript API that workero does not wrap.

[`Workero.js_value`](./Workero.md#type-js_value) is the type of a raw, unchecked JavaScript value. It is the same type as `Js_of_ocaml.Js.Unsafe.any`. Module signatures show the jsoo name. Use `Js_of_ocaml.Js` to read fields, call methods and convert strings. Workero already wraps timers, `Date`, `crypto` and `console`. See [JavaScript globals](./globals.md).

```ocaml
open Js_of_ocaml

let global name = Js.Unsafe.get Js.Unsafe.global (Js.string name)

let handler req _env _ctx =
  let raw : Workero.js_value = Workero.Request.to_js req in
  let method_ : Js.js_string Js.t = Js.Unsafe.get raw (Js.string "method") in
  let done_ : string Workero.Promise.t =
    Workero.Promise.of_js ~decode:Workero.Decode.string
      (Js.Unsafe.meth_call (global "Promise") "resolve"
         [| Js.Unsafe.inject (Js.string "done") |])
  in
  let word = Workero.Promise.await done_ in
  Workero.Response.text (Js.to_string method_ ^ " " ^ word ^ "\n")

let () = Workero.serve handler
```
[`Workero.Promise.of_js`](./Workero-Promise.md#val-of_js) takes a `~decode` function. It turns the resolved JavaScript value into an OCaml value. If `decode` raises, the Promise rejects and [`Workero.Promise.await`](./Workero-Promise.md#val-await) re-raises that exception, for example `Invalid_argument "Workero.Decode: expected string, got number"`.


## Decode

[`Workero.Decode`](./Workero-Decode.md) has decoders for raw values: `js` (undecoded), `unit`, `string`, `int`, `float`, `bool`, `bytes`, `option`, `list` and `field name decoder`. A decoder is a function from [`Workero.js_value`](./Workero.md#type-js_value). It raises `Invalid_argument` with the expected and the actual JavaScript type when the value does not fit. `int` also rejects a number with a fraction or outside the range of `int`. `bytes` rejects array elements outside 0\..255. `field` reads one property of an object or a function:

```ocaml
open Js_of_ocaml

let global name = Js.Unsafe.get Js.Unsafe.global (Js.string name)

let user =
  let raw =
    Js.Unsafe.obj
      [|
        ("name", Js.Unsafe.inject (Js.string "ada"));
        ("age", Js.Unsafe.inject 36);
      |]
  in
  Workero.Promise.of_js
    ~decode:(fun v -> Workero.Decode.(field "name" string v, field "age" int v))
    (Js.Unsafe.meth_call (global "Promise") "resolve" [| raw |])

let handler _req _env _ctx =
  let name, age = Workero.Promise.await user in
  Workero.Response.text (Printf.sprintf "%s is %d\n" name age)

let () = Workero.serve handler
```
Add `js_of_ocaml` to `libraries` next to `workero`.
