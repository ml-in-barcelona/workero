module Js = Js_of_ocaml.Js
open Effect
open Effect.Deep
open Internal

type _ Effect.t += Await : js -> 'a Effect.t

let await p = perform (Await p)

let promising (f : 'a) : js =
  call (global "__promisify") [| Js.Unsafe.inject f |]

let reason_to_string (v : js) = Js.to_string (call (global "String") [| v |])
let resume f = ignore (call (promising f) [||])

let run (f : unit -> js) : js =
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
