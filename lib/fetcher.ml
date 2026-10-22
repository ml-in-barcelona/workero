open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Fetcher.of_env"
    ~what:"a service binding or an assets binding" ~methods:[ "fetch" ] env name

let fetch ?method_ ?headers ?body fetcher url =
  let init =
    Wire.fetch_init ~who:"Workero.Fetcher.fetch" ?method_ ?headers ?body ()
  in
  Response.of_js
    (Binding.call ~decode:Decode.js fetcher "fetch" [| str url; init |])

let fetch_request fetcher req =
  Response.of_js
    (Binding.call ~decode:Decode.js fetcher "fetch" [| Request.to_js req |])

let of_js (v : js) : t = v
let to_js (t : t) : js = t
