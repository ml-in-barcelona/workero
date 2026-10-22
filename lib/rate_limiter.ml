open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Rate_limiter.of_env" ~what:"a rate limiter"
    ~methods:[ "limit" ] env name

let limit t key =
  Binding.call
    ~decode:(Decode.field "success" Decode.bool)
    t "limit"
    [| Binding.options [ ("key", str key) ] |]

let of_js (v : js) : t = v
let to_js (t : t) : js = t
