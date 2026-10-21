type timeout = Internal.js
type interval = Internal.js

let int_arg n = Internal.Js.Unsafe.inject (Internal.Js.float (float_of_int n))

let callback f =
  Internal.Js.Unsafe.inject (Internal.Js.wrap_callback (fun () -> f ()))

let set_timeout f ms =
  Internal.call (Internal.global "setTimeout") [| callback f; int_arg ms |]

let clear_timeout t =
  ignore (Internal.call (Internal.global "clearTimeout") [| t |])

let set_interval f ms =
  Internal.call (Internal.global "setInterval") [| callback f; int_arg ms |]

let clear_interval t =
  ignore (Internal.call (Internal.global "clearInterval") [| t |])

let sleep ms =
  Promise.make (fun ~resolve ~reject:_ ->
      ignore (set_timeout (fun () -> resolve ()) ms))
