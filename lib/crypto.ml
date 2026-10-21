let crypto () = Internal.global "crypto"

let random_uuid () =
  Internal.Js.to_string
    (Internal.Js.Unsafe.coerce (Internal.meth (crypto ()) "randomUUID" [||]))

let max_bytes = 65536

let random_bytes n =
  if n < 0 || n > max_bytes then
    invalid_arg (Printf.sprintf "Workero.Crypto.random_bytes: %d" n);
  let buf =
    Internal.Js.Unsafe.new_obj
      (Internal.global "Uint8Array")
      [| Internal.Js.Unsafe.inject (Internal.Js.float (float_of_int n)) |]
  in
  ignore (Internal.meth (crypto ()) "getRandomValues" [| buf |]);
  String.init n (fun i ->
      Char.chr (Internal.int_of_js (Internal.Js.Unsafe.get buf i)))
