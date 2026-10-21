module Js = Js_of_ocaml.Js
open Internal

type t = js

let of_env env name =
  Binding.of_env ~who:"Workero.KV.of_env" ~what:"a KV namespace"
    ~methods:[ "get"; "put"; "delete"; "list" ]
    env name

let get kv key =
  let v : Js.js_string Js.t option = Binding.call_opt kv "get" [| str key |] in
  Option.map Js.to_string v

let put ?expiration_ttl kv key value =
  let options =
    match expiration_ttl with
    | Some ttl ->
        [ Binding.options [ ("expirationTtl", Js.Unsafe.inject (ttl : int)) ] ]
    | None -> []
  in
  let _ : js =
    Binding.call kv "put" (Array.of_list (str key :: str value :: options))
  in
  ()

let delete kv key =
  let _ : js = Binding.call kv "delete" [| str key |] in
  ()

let list ?prefix kv =
  let rec pages cursor acc =
    let options =
      Option.fold prefix ~none:[] ~some:(fun p -> [ ("prefix", str p) ])
      @ Option.fold cursor ~none:[] ~some:(fun c -> [ ("cursor", str c) ])
    in
    let page : js = Binding.call kv "list" [| Binding.options options |] in
    let names =
      Binding.array_to_list
        (fun key -> Js.to_string (Js.Unsafe.get key "name"))
        (Js.Unsafe.get page "keys")
    in
    let acc = List.rev_append names acc in
    if Js.to_bool (Js.Unsafe.get page "list_complete") then List.rev acc
    else
      match get_string page "cursor" with
      | Some _ as cursor -> pages cursor acc
      | None ->
          raise
            (Js_error "Workero.KV.list: incomplete listing without a cursor")
  in
  pages None []
