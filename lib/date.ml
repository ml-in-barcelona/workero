let now () =
  Internal.Js.to_float
    (Internal.Js.Unsafe.coerce
       (Internal.meth (Internal.global "Date") "now" [||]))

let to_iso_string t =
  let d =
    Internal.Js.Unsafe.new_obj (Internal.global "Date")
      [| Internal.Js.Unsafe.inject (Internal.Js.float t) |]
  in
  if
    Float.is_nan
      (Internal.Js.float_of_number
         (Internal.Js.Unsafe.coerce (Internal.meth d "getTime" [||])))
  then invalid_arg (Printf.sprintf "Workero.Date.to_iso_string: %g" t)
  else
    Internal.Js.to_string
      (Internal.Js.Unsafe.coerce (Internal.meth d "toISOString" [||]))
