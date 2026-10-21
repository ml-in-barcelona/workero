open Internal

type t = js

let country cf = get_string cf "country"
let region cf = get_string cf "region"
let city cf = get_string cf "city"
let colo cf = get_string cf "colo"
let timezone cf = get_string cf "timezone"
let asn cf = get_int cf "asn"
let of_js (v : js) : t = v
let to_js (t : t) : js = t
