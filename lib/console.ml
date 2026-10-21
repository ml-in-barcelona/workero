let write level s =
  ignore (Internal.meth (Internal.global "console") level [| Internal.str s |])

let log = write "log"
let info = write "info"
let warn = write "warn"
let error = write "error"
let debug = write "debug"
