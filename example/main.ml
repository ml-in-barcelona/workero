open Js_of_ocaml

exception Failed

let global name = Js.Unsafe.get Js.Unsafe.global name

let promise_with f =
  let r = Js.Unsafe.meth_call (global "Promise") "withResolvers" [||] in
  f r;
  Js.Unsafe.get r "promise"

let sleep ms =
  promise_with (fun r ->
      ignore
        (Js.Unsafe.fun_call (global "setTimeout")
           [| Js.Unsafe.get r "resolve"; Js.Unsafe.inject (ms : int) |]))

let reject () =
  promise_with (fun r ->
      ignore
        (Js.Unsafe.fun_call (Js.Unsafe.get r "reject")
           [| Js.Unsafe.inject (Js.string "nope") |]))

let backend =
  match Sys.backend_type with
  | Native -> "native"
  | Bytecode -> "bytecode"
  | Other s -> s

let webassembly =
  Js.to_string
    (Js.typeof (Js.Unsafe.get Js.Unsafe.global (Js.string "WebAssembly")))

let requests = ref 0

let info () =
  incr requests;
  Printf.sprintf
    "hello from OCaml %s\n\
     backend: %s (typeof WebAssembly: %s, word size: %d, int size: %d)\n\
     requests served by this isolate: %d (1 = cold start)\n\
     timing: not measured here, Workers freeze the clock during CPU work\n"
    Sys.ocaml_version backend webassembly Sys.word_size Sys.int_size !requests

let handler req env =
  let open Workero in
  let url = Request.url req in
  match (Request.method_ req, URL.path url) with
  | "GET", "/" -> Response.text (info ())
  | "GET", "/hello" ->
      let name = Option.value (URL.query url "name") ~default:"world" in
      Response.text (Printf.sprintf "hello, %s\n" name)
  | "POST", "/echo" -> Response.text (Request.text req)
  | _, "/env" ->
      Response.text
        (Option.value (Env.var env "GREETING") ~default:"unset" ^ "\n")
  | _, "/fail" -> raise Failed
  | _, "/reject" ->
      ignore (await (reject ()));
      Response.text "unreachable\n"
  | _, "/sleep" ->
      ignore (await (sleep 50));
      Response.text "slept\n"
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.fetch handler
