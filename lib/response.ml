module Js = Js_of_ocaml.Js
open Internal

type t = js

let null_body_statuses = [ 204; 205; 304 ]
let code = function None -> 200 | Some s -> Status.to_int s

let build ?content_type ~status ~headers ~empty_body body =
  if status < 200 || status > 599 then
    invalid_arg
      (Printf.sprintf "Workero.Response: status %d is outside 200..599" status);
  let body = if empty_body then Js.Unsafe.inject Js.null else body in
  if List.mem status null_body_statuses && not (is_nullish body) then
    invalid_arg
      (Printf.sprintf "Workero.Response: status %d allows no body" status);
  let init =
    (if status = 200 then [] else [ ("status", Js.Unsafe.inject status) ])
    @
    if headers = [] && content_type = None then []
    else
      let h = Wire.headers_of_list headers in
      Option.iter
        (fun ct ->
          if not (Js.to_bool (meth h "has" [| str "content-type" |])) then
            ignore (meth h "set" [| str "content-type"; str ct |]))
        content_type;
      [ ("headers", h) ]
  in
  Js.Unsafe.new_obj (global "Response")
    (match init with
    | [] -> [| body |]
    | _ -> [| body; Js.Unsafe.obj (Array.of_list init) |])

let text ?status ?(headers = []) body =
  build ~status:(code status) ~headers ~empty_body:(body = "") (str body)

let html ?status ?(headers = []) body =
  build ~content_type:"text/html; charset=utf-8" ~status:(code status) ~headers
    ~empty_body:(body = "") (str body)

let make ?status ?(headers = []) body =
  build ~status:(code status) ~headers ~empty_body:(body = "")
    (Wire.body_of_string body)

let empty ?(headers = []) status =
  build ~status:(Status.to_int status) ~headers ~empty_body:true
    (Js.Unsafe.inject Js.null)

let of_stream ?status ?(headers = []) s =
  build ~status:(code status) ~headers ~empty_body:false (Stream.to_js s)

let stream ?status ?headers ctx f =
  let writer, readable = Stream.pipe () in
  Context.wait_until ctx (fun () ->
      match f writer with
      | () -> ( try Stream.Writer.close writer with Promise.Js_error _ -> ())
      | exception e ->
          let message = "Workero.Response.stream: " ^ Printexc.to_string e in
          ignore (meth (global "console") "error" [| str message |]);
          Stream.Writer.abort ~reason:message writer);
  of_stream ?status ?headers readable

let redirect ?status url =
  let status = match status with None -> 302 | Some s -> Status.to_int s in
  if Js.to_bool (meth (global "URL") "canParse" [| str url |]) then
    meth (global "Response") "redirect" [| str url; Js.Unsafe.inject status |]
  else empty ~headers:[ ("location", url) ] (`Status status)

let status r = int_of_js (Js.Unsafe.get r "status")
let header = Wire.header
let header_all = Wire.header_all
let headers = Wire.headers

let body r : Stream.t option =
  let v = Js.Unsafe.get r "body" in
  if is_nullish v then None else Some (Stream.of_js v)

let clone r : t = Binding.invoke r "clone" [||]

let copy ?status ?headers:new_headers r =
  let status =
    match status with
    | Some s -> Status.to_int s
    | None -> int_of_js (Js.Unsafe.get r "status")
  in
  let headers = Option.value new_headers ~default:(Wire.headers r) in
  build ~status ~headers ~empty_body:false (Js.Unsafe.get r "body")

let body_text = Wire.text
let body_bytes = Wire.bytes
let of_js (v : js) : t = v
let to_js (t : t) : js = t
