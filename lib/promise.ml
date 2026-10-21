module Js = Js_of_ocaml.Js
module Jp = Js_of_ocaml.Promise
open Internal

type 'a t = 'a Jp.t
type error = Jp.error

exception Js_error = Async.Js_error

let error_of_js = Jp.error_of_any
let error_to_js = Jp.error_to_any

let error_of_string msg =
  error_of_js (Js.Unsafe.new_obj (global "Error") [| str msg |])

let error_of_exn = Async.error_of_exn

let error_to_string e =
  let v = error_to_js e in
  try Js.to_string (call (global "String") [| v |])
  with Js.Js_error.Exn _ -> (
    let to_string =
      Js.Unsafe.get (Js.Unsafe.get (global "Object") "prototype") "toString"
    in
    try Js.to_string (meth to_string "call" [| v |])
    with Js.Js_error.Exn _ -> "<unprintable JS value>")

let () =
  Printexc.register_printer (function
    | Js_error e -> Some (Printf.sprintf "Js_error(%S)" (error_to_string e))
    | _ -> None)

let make f =
  Jp.make (fun ~resolve ~reject ->
      try f ~resolve ~reject with e -> reject (error_of_exn e))

let resolve = Jp.resolve
let reject = Jp.reject

let map f p =
  Jp.then_
    (fun x ->
      match f x with
      | y -> Jp.resolve y
      | exception e -> Jp.reject (error_of_exn e))
    p

let bind f p =
  Jp.then_ (fun x -> try f x with e -> Jp.reject (error_of_exn e)) p

let all = Jp.all
let race = Jp.race
let any = Jp.any
let all_settled = Jp.all_settled
let await = Async.await

let of_js ~decode p =
  Jp.then_
    (fun v ->
      match decode v with
      | x -> Jp.resolve x
      | exception e -> Jp.reject (error_of_exn e))
    (Jp.of_any p)

let to_js = Jp.to_any
