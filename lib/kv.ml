module Js = Js_of_ocaml.Js
open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.KV.of_env" ~what:"a KV namespace"
    ~methods:[ "get"; "put"; "delete"; "list" ]
    env name

let get kv key = Binding.call_opt ~decode:Decode.string kv "get" [| str key |]

let put ?expiration_ttl kv key value =
  let options =
    match expiration_ttl with
    | Some ttl ->
        [ Binding.options [ ("expirationTtl", Js.Unsafe.inject (ttl : int)) ] ]
    | None -> []
  in
  Binding.call ~decode:Decode.unit kv "put"
    (Array.of_list (str key :: str value :: options))

let delete kv key = Binding.call ~decode:Decode.unit kv "delete" [| str key |]

let list ?prefix kv =
  let rec pages cursor acc =
    let options =
      Option.fold prefix ~none:[] ~some:(fun p -> [ ("prefix", str p) ])
      @ Option.fold cursor ~none:[] ~some:(fun c -> [ ("cursor", str c) ])
    in
    let decode =
      let open Decode in
      fun page ->
        ( field "keys" (list (field "name" string)) page,
          field "list_complete" bool page,
          field "cursor" (option string) page )
    in
    let names, complete, cursor =
      Binding.call ~decode kv "list" [| Binding.options options |]
    in
    let acc = List.rev_append names acc in
    match (complete, cursor) with
    | true, _ -> List.rev acc
    | false, Some _ -> pages cursor acc
    | false, None ->
        failwith "Workero.KV.list: incomplete listing without a cursor"
  in
  pages None []

let of_js (v : js) : t = v
let to_js (t : t) : js = t
