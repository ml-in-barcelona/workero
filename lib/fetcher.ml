module Js = Js_of_ocaml.Js
open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Fetcher.of_env"
    ~what:"a service binding or an assets binding" ~methods:[ "fetch" ] env name

let fetch ?signal ?method_ ?headers ?body fetcher url =
  let init =
    Wire.fetch_init ~who:"Workero.Fetcher.fetch" ?signal ?method_ ?headers ?body
      ()
  in
  Response.of_js
    (Binding.call ~decode:Decode.js fetcher "fetch" [| str url; init |])

let fetch_request ?signal fetcher req =
  let req =
    match signal with
    | None -> Request.to_js req
    | Some s ->
        Js.Unsafe.new_obj (global "Request")
          [|
            Request.to_js req;
            Js.Unsafe.obj [| ("signal", Abort_signal.to_js s) |];
          |]
  in
  Response.of_js (Binding.call ~decode:Decode.js fetcher "fetch" [| req |])

let of_js (v : js) : t = v
let to_js (t : t) : js = t
