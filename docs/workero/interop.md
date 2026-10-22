
# JavaScript interop

Use `of_js` and `to_js` to cross the JavaScript boundary. For example, [`Workero.Request`](./Workero-Request.md), [`Workero.Response`](./Workero-Response.md), [`Workero.Stream`](./Workero-Stream.md), [`Workero.Env`](./Workero-Env.md), [`Workero.Fetcher`](./Workero-Fetcher.md), [`Workero.Queue`](./Workero-Queue.md), [`Workero.Durable_object.State`](./Workero-Durable_object-State.md) and [`Workero.Durable_object.Sql`](./Workero-Durable_object-Sql.md) wrap raw JavaScript values. Check each linked module's signature for the conversion types. [`Workero.Promise.of_js`](./Workero-Promise.md#val-of_js) needs a decoder; [`Workero.URL`](./Workero-URL.md) parses strings and has no `of_js`/`to_js` pair.

[`Workero.js_value`](./Workero.md#type-js_value) is the type of a raw, unchecked JavaScript value. It is the same type as `Js_of_ocaml.Js.Unsafe.any`. Module signatures show the jsoo name. Use `Js_of_ocaml.Js` to read fields, call methods and convert strings. Workero already wraps timers, `Date`, random-value functions, and `console`. See [Timers, time, and randomness](./globals.md) and [Logging](./logging.md).

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


## JSON values and environment bindings

[`Workero.JSON.of_js`](./Workero-JSON.md#val-of_js) converts a JavaScript value to `Jsonkit.t` using `JSON.stringify`. [`Workero.JSON.to_js`](./Workero-JSON.md#val-to_js) converts a `Jsonkit.t` back using `JSON.parse`. These conversions copy JSON data; they do not keep the original object. `of_js` rejects values that cannot be serialized, such as a cyclic object or `BigInt`. `to_js` rejects non-JSON floats such as `nan`.

[`Workero.Env.to_js`](./Workero-Env.md#val-to_js) exposes the raw binding object if you need an API that workero does not wrap. For ordinary bindings use the typed `of_env` functions. [`Workero.Env.var`](./Workero-Env.md#val-var) returns a string or `None`, [`Workero.Env.secret`](./Workero-Env.md#val-secret) requires a string and raises `Invalid_argument` if it is absent or has another type, and [`Workero.Env.json`](./Workero-Env.md#val-json) returns an object or array as `Jsonkit.t` (or `None` for a non-object or missing value). See [Variables and secrets](./env.md).


## Durable Object sockets and SQL

[`Workero.Websocket.serialize_attachment`](./Workero-Websocket.md#val-serialize_attachment) converts a `Jsonkit.t` to a raw JavaScript value and attaches it to a socket accepted through [`Workero.Durable_object.State.accept_websocket`](./Workero-Durable_object-State.md#val-accept_websocket). The attachment survives hibernation. [`Workero.Websocket.deserialize_attachment`](./Workero-Websocket.md#val-deserialize_attachment) converts it back to `Jsonkit.t option`. `serialize_attachment` raises [`Workero.Js_error`](./Workero.md#exception-Js_error) on a socket accepted with [`Workero.Websocket.accept`](./Workero-Websocket.md#val-accept); that socket cannot hibernate. See [Durable Objects](./durable_objects.md) for the socket lifecycle.

[`Workero.Durable_object.Storage.sql`](./Workero-Durable_object-Storage.md#val-sql) provides synchronous SQLite access on a Durable Object. [`Workero.Sql_value.to_js`](./Workero-Sql_value.md#val-to_js) and [`Workero.Sql_value.of_js`](./Workero-Sql_value.md#val-of_js) convert individual SQL values to and from raw JavaScript values. They are not JSON conversions: binary values use `Uint8Array`, and JavaScript numbers can lose integer precision. Check the linked signatures before passing raw values to an external SQL API.
