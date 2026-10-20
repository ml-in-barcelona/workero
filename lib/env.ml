open Internal

type t = js

let var env name = get_string env name
let of_js (v : js) : t = v
let to_js (t : t) : js = t
