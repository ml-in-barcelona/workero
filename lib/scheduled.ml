open Internal

type t = js

let cron t = Option.value (get_string t "cron") ~default:""

let scheduled_time t =
  let v = Js.Unsafe.get t "scheduledTime" in
  if typeof v = "number" then Js.float_of_number (Js.Unsafe.coerce v) else 0.

let of_js (v : js) : t = v
let to_js (t : t) : js = t
