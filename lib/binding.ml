module Js = Js_of_ocaml.Js
open Internal

let describe v =
  match typeof v with
  | "object" -> "an object"
  | "undefined" -> "undefined"
  | t -> "a " ^ t

let of_env ~who ~what ~methods env name : js =
  let env = Env.to_js env in
  let own = Js.to_bool (meth (global "Object") "hasOwn" [| env; str name |]) in
  if not own then
    invalid_arg (Printf.sprintf "%s: binding %S not found" who name);
  let v = Js.Unsafe.get env name in
  let is_method m =
    (not (is_nullish v)) && typeof (Js.Unsafe.get v m) = "function"
  in
  if typeof v <> "object" || is_nullish v then
    invalid_arg
      (Printf.sprintf "%s: binding %S is %s, not %s" who name (describe v) what);
  (match List.find_opt (fun m -> not (is_method m)) methods with
  | Some m ->
      invalid_arg
        (Printf.sprintf "%s: binding %S is an object without method %s, not %s"
           who name m what)
  | None -> ());
  v

let guard f =
  match f () with
  | v -> v
  | exception Js.Js_error.Exn e ->
      raise
        (Promise.Js_error
           (Promise.error_of_js (Js.Unsafe.inject (Js.Js_error.to_error e))))

let invoke obj name args : 'a = guard (fun () -> meth obj name args)

let call ~decode obj name args =
  Promise.await (Promise.of_js ~decode (invoke obj name args))

let call_opt ~decode obj name args =
  call ~decode:(Decode.option decode) obj name args

let options fields = Js.Unsafe.obj (Array.of_list fields)
