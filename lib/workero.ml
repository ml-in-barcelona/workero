open Js_of_ocaml
open Effect
open Effect.Deep

type js = Js.Unsafe.any

exception Js_error of string

type _ Effect.t += Await : js -> js Effect.t

let global name = Js.Unsafe.get Js.Unsafe.global name
let call f args = Js.Unsafe.fun_call f args
let meth o name args = Js.Unsafe.meth_call o name args
let str s = Js.Unsafe.inject (Js.string s)

let promising (f : 'a) : js =
  call (global "__promisify") [| Js.Unsafe.inject f |]

let reason_to_string (v : js) = Js.to_string (call (global "String") [| v |])
let resume f = ignore (call (promising f) [||])
let await p = perform (Await p)

let async (f : unit -> js) : js =
  let r = meth (global "Promise") "withResolvers" [||] in
  let settle name v = ignore (call (Js.Unsafe.get r name) [| v |]) in
  try_with
    (fun () ->
      match f () with
      | v -> settle "resolve" v
      | exception e ->
          let err =
            Js.Unsafe.new_obj (global "Error") [| str (Printexc.to_string e) |]
          in
          settle "reject" err)
    ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          match e with
          | Await p ->
              Some
                (fun (k : (a, _) continuation) ->
                  let on_ok =
                    Js.wrap_callback (fun (v : js) ->
                        resume (fun () -> continue k v))
                  in
                  let on_err =
                    Js.wrap_callback (fun (v : js) ->
                        let msg = reason_to_string v in
                        resume (fun () -> discontinue k (Js_error msg)))
                  in
                  ignore
                    (meth p "then"
                       [| Js.Unsafe.inject on_ok; Js.Unsafe.inject on_err |]))
          | _ -> None);
    };
  Js.Unsafe.get r "promise"

module URL = struct
  include Uri

  let query u name =
    match get_query_param' u name with Some (v :: _) -> Some v | _ -> None
end

module Request = struct
  type t = js

  let method_ r = Js.to_string (Js.Unsafe.get r "method")
  let url r = Uri.of_string (Js.to_string (Js.Unsafe.get r "url"))

  let header r name =
    let v : Js.js_string Js.t Js.opt =
      meth (Js.Unsafe.get r "headers") "get" [| str name |]
    in
    Option.map Js.to_string (Js.Opt.to_option v)

  let text r = Js.to_string (Js.Unsafe.coerce (await (meth r "text" [||])))
end

module Response = struct
  type t = js

  let text ?(status = 200) ?(headers = []) body =
    let headers =
      Js.Unsafe.obj
        (Array.of_list (List.map (fun (k, v) -> (k, str v)) headers))
    in
    let init =
      Js.Unsafe.obj
        [| ("status", Js.Unsafe.inject status); ("headers", headers) |]
    in
    Js.Unsafe.new_obj (global "Response") [| str body; init |]
end

module Env = struct
  type t = js

  let var env name =
    let v = Js.Unsafe.get env name in
    if Js.to_string (Js.typeof (Js.Unsafe.coerce v)) = "string" then
      Some (Js.to_string (Js.Unsafe.coerce v))
    else None
end

let fetch handler =
  let fetch (request : js) (env : js) (_ctx : js) : js =
    async (fun () -> handler request env)
  in
  let o = Js.Unsafe.obj [| ("fetch", promising fetch) |] in
  Js.Unsafe.set Js.Unsafe.global "__workero" o
