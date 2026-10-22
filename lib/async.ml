module Js = Js_of_ocaml.Js
module Jp = Js_of_ocaml.Promise
open Effect
open Effect.Deep
open Internal

exception Js_error of Jp.error

type _ Effect.t += Await : 'a Jp.t -> 'a Effect.t

let blocked = ref None

let await p =
  match !blocked with
  | Some who -> invalid_arg (who ^ ": Promise.await is not allowed here")
  | None -> perform (Await p)

let no_await ~who f =
  let saved = !blocked in
  blocked := Some who;
  Fun.protect ~finally:(fun () -> blocked := saved) f

let promising (f : 'a) : js =
  call (Js.Unsafe.get (global "__workero") "promisify") [| Js.Unsafe.inject f |]

let carried = "workero_exn"

let error_of_exn e =
  let err =
    Js.Unsafe.new_obj (global "Error") [| str (Printexc.to_string e) |]
  in
  Js.Unsafe.set err carried (Js.Unsafe.inject e);
  Jp.error_of_any err

let exn_of_error err =
  let v = Jp.error_to_any err in
  if
    typeof v = "object"
    && (not (is_nullish v))
    && typeof (Js.Unsafe.get v carried) <> "undefined"
  then (Js.Unsafe.get v carried : exn)
  else Js_error err

let error_to_js = function
  | Js_error e -> Jp.error_to_any e
  | e -> Jp.error_to_any (error_of_exn e)

let resume ~reject f =
  ignore (meth (call (promising f) [||]) "catch" [| reject |])

let run (f : unit -> js) : js =
  let r = lazy (meth (global "Promise") "withResolvers" [||]) in
  let field name = Js.Unsafe.get (Lazy.force r) name in
  let early = ref None in
  let finish name v =
    if Lazy.is_val r then ignore (call (field name) [| v |])
    else
      early :=
        Some
          (if name = "resolve" then v
           else meth (global "Promise") "reject" [| v |])
  in
  try_with
    (fun () ->
      match f () with
      | v -> finish "resolve" v
      | exception e -> finish "reject" (error_to_js e))
    ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          match e with
          | Await p ->
              Some
                (fun (k : (a, _) continuation) ->
                  let resume = resume ~reject:(field "reject") in
                  ignore
                    (Jp.then_
                       ~on_error:(fun e ->
                         resume (fun () -> discontinue k (exn_of_error e));
                         Jp.resolve ())
                       (fun v ->
                         resume (fun () -> continue k v);
                         Jp.resolve ())
                       p))
          | _ -> None);
    };
  match !early with Some v -> v | None -> field "promise"
