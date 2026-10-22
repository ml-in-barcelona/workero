open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Secret_store.of_env"
    ~what:"a Secrets Store secret" ~methods:[ "get" ] env name

let get store = Binding.call_opt ~decode:Decode.string store "get" [||]
let of_js (v : js) : t = v
let to_js (t : t) : js = t
