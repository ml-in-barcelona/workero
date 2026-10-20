open Js_of_ocaml

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

let handler req env _ctx =
  let open Workero in
  let url = Request.url req in
  match (Request.method_ req, URL.path url) with
  | GET, "/" -> Response.text (info ())
  | GET, "/hello" ->
      let name = Option.value (URL.query url "name") ~default:"world" in
      Response.text (Printf.sprintf "hello, %s\n" name)
  | POST, "/echo" -> Response.text (Request.text req)
  | _, "/env" ->
      Response.text
        (Option.value (Env.var env "GREETING") ~default:"unset" ^ "\n")
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
