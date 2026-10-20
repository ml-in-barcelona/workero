open Js_of_ocaml
open Effect
open Effect.Deep

type js = Js.Unsafe.any

exception Js_error of string

let global name = Js.Unsafe.get Js.Unsafe.global name
let call f args = Js.Unsafe.fun_call f args
let meth o name args = Js.Unsafe.meth_call o name args
let str s = Js.Unsafe.inject (Js.string s)

module Raw_promise = struct
  type 'a t = js

  let make (f : resolve:('a -> unit) -> reject:(string -> unit) -> unit) : 'a t
      =
    let executor =
      Js.wrap_callback (fun (res : js) (rej : js) ->
          let resolve (v : 'a) = ignore (call res [| Js.Unsafe.inject v |]) in
          let reject msg =
            let err = Js.Unsafe.new_obj (global "Error") [| str msg |] in
            ignore (call rej [| err |])
          in
          f ~resolve ~reject)
    in
    Js.Unsafe.new_obj (global "Promise") [| Js.Unsafe.inject executor |]

  let resolve (v : 'a) : 'a t =
    meth (global "Promise") "resolve" [| Js.Unsafe.inject v |]

  let reject msg : 'a t =
    let err = Js.Unsafe.new_obj (global "Error") [| str msg |] in
    meth (global "Promise") "reject" [| err |]

  let of_js (p : js) : 'a t = p
  let to_js (p : 'a t) : js = p
end

type _ Effect.t += Await : 'a Raw_promise.t -> 'a Effect.t

let promising (f : 'a) : js =
  call (global "__promisify") [| Js.Unsafe.inject f |]

let reason_to_string (v : js) = Js.to_string (call (global "String") [| v |])
let resume f = ignore (call (promising f) [||])

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
                    Js.wrap_callback (fun (v : a) ->
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

module Promise = struct
  include Raw_promise

  let await p = perform (Await p)
end

module URL = struct
  type t = { secure : bool; url : Url.http_url }

  let of_string s =
    match Url.url_of_string s with
    | Some (Url.Http url) -> Some { secure = false; url }
    | Some (Url.Https url) -> Some { secure = true; url }
    | Some (Url.File _) | None -> None

  let to_string t =
    Url.string_of_url (if t.secure then Url.Https t.url else Url.Http t.url)

  let scheme t = if t.secure then "https" else "http"
  let host t = t.url.hu_host
  let port t = t.url.hu_port
  let path t = "/" ^ t.url.hu_path_string
  let query_args t = t.url.hu_arguments

  let query_all t name =
    List.filter_map
      (fun (k, v) -> if String.equal k name then Some v else None)
      t.url.hu_arguments

  let query t name =
    List.find_map
      (fun (k, v) -> if String.equal k name then Some v else None)
      t.url.hu_arguments
end

module Request = struct
  type t = js

  let method_ r = Js.to_string (Js.Unsafe.get r "method")

  let url r =
    let s = Js.to_string (Js.Unsafe.get r "url") in
    match URL.of_string s with
    | Some u -> u
    | None -> invalid_arg ("Workero.Request.url: " ^ s)

  let header r name =
    let v : Js.js_string Js.t Js.opt =
      meth (Js.Unsafe.get r "headers") "get" [| str name |]
    in
    Option.map Js.to_string (Js.Opt.to_option v)

  let text r =
    let p : Js.js_string Js.t Promise.t = Promise.of_js (meth r "text" [||]) in
    Js.to_string (Promise.await p)
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
