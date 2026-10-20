type t = GET | HEAD | POST | PUT | DELETE | PATCH | OPTIONS | Other of string

let of_string s =
  match s with
  | "GET" -> GET
  | "HEAD" -> HEAD
  | "POST" -> POST
  | "PUT" -> PUT
  | "DELETE" -> DELETE
  | "PATCH" -> PATCH
  | "OPTIONS" -> OPTIONS
  | _ -> Other s

let to_string = function
  | GET -> "GET"
  | HEAD -> "HEAD"
  | POST -> "POST"
  | PUT -> "PUT"
  | DELETE -> "DELETE"
  | PATCH -> "PATCH"
  | OPTIONS -> "OPTIONS"
  | Other s -> s
