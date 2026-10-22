open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.Hyperdrive.of_env" ~what:"a Hyperdrive binding"
    ~methods:[] env name

let read field decode t = Decode.field field decode t
let connection_string t = read "connectionString" Decode.string t
let host t = read "host" Decode.string t
let port t = read "port" Decode.int t
let user t = read "user" Decode.string t
let password t = read "password" Decode.string t
let database t = read "database" Decode.string t
let of_js (v : js) : t = v
let to_js (t : t) : js = t
