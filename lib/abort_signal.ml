module Js = Js_of_ocaml.Js
open Internal

type t = js

let aborted s = Js.to_bool (Js.Unsafe.get s "aborted")

let reason s =
  if aborted s then Some (Promise.error_of_js (Js.Unsafe.get s "reason"))
  else None

let is_abort = function
  | Promise.Js_error e -> (
      let v = Promise.error_to_js e in
      typeof v = "object"
      && (not (is_nullish v))
      &&
      match get_string v "name" with
      | Some ("AbortError" | "TimeoutError") -> true
      | _ -> false)
  | _ -> false

let throw_if_aborted s =
  match reason s with Some e -> raise (Promise.Js_error e) | None -> ()

let static name args = meth (global "AbortSignal") name args

let timeout ms =
  static "timeout" [| Js.Unsafe.inject (Js.float (float_of_int ms)) |]

let any signals =
  static "any" [| Js.Unsafe.inject (Js.array (Array.of_list signals)) |]

let aborted_now ?reason () =
  match reason with
  | None -> static "abort" [||]
  | Some r -> static "abort" [| abort_reason r |]

let listen_with listener s f =
  ignore
    (meth s "addEventListener"
       [|
         str "abort";
         listener f;
         Js.Unsafe.obj [| ("once", Js.Unsafe.inject Js._true) |];
       |])

let listen = listen_with (fun f -> Js.Unsafe.inject (Js.wrap_callback f))
let listen_fiber = listen_with Async.promising

let on_abort s f =
  let run () =
    ignore
      (Async.run (fun () ->
           (try f ()
            with e ->
              Console.error
                ("Workero.Abort_signal.on_abort: " ^ Printexc.to_string e));
           Js.Unsafe.inject Js.undefined))
  in
  if aborted s then run ()
  else
    listen_fiber s (fun (_ : js) ->
        run ();
        Js.Unsafe.inject Js.undefined)

let to_promise s =
  Promise.make (fun ~resolve:_ ~reject ->
      let fail () = reject (Promise.error_of_js (Js.Unsafe.get s "reason")) in
      if aborted s then fail ()
      else
        listen s (fun (_ : js) ->
            fail ();
            Js.Unsafe.inject Js.undefined))

let of_js (v : js) : t = v
let to_js (t : t) : js = t
