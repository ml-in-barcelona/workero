open Workero

let show res =
  Printf.sprintf "%d|%s|%s" (Response.status res)
    (Option.value (Response.header res "x-backend") ~default:"none")
    (Response.body_text res)

let hex s =
  String.concat ""
    (List.init (String.length s) (fun i ->
         Printf.sprintf "%02x" (Char.code s.[i])))

let handle req env _ctx =
  let url = Request.url req in
  let backend () = Fetcher.of_env env "BACKEND" in
  match URL.path url with
  | "/fetcher/get" ->
      Some
        (Response.text
           (show (Fetcher.fetch (backend ()) "http://any.host/echo?x=1")))
  | "/fetcher/post" ->
      Some
        (Response.text
           (show
              (Fetcher.fetch ~method_:POST
                 ~headers:[ ("x-a", "from ocaml") ]
                 ~body:"payload" (backend ()) "http://any.host/echo")))
  | "/fetcher/bytes" ->
      Some
        (Response.text
           (show
              (Fetcher.fetch ~method_:PUT ~body:"\x00\xff\x80\n" (backend ())
                 "http://any.host/hex")))
  | "/fetcher/status" ->
      Some
        (Response.text
           (show (Fetcher.fetch (backend ()) "http://any.host/teapot")))
  | "/fetcher/forward" ->
      Some (Response.text (show (Fetcher.fetch_request (backend ()) req)))
  | "/fetcher/forward-clone" ->
      let copy = Request.clone req in
      let res = Fetcher.fetch_request (backend ()) copy in
      Some (Response.text (Request.text req ^ "||" ^ show res))
  | "/fetcher/raises" -> (
      match Fetcher.fetch (backend ()) "http://any.host/boom" with
      | _ -> Some (Response.text "unreachable")
      | exception Js_error e ->
          Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e)))
  | "/fetcher/shape" ->
      let name = Option.value (URL.query url "name") ~default:"" in
      Some
        (Response.text
           (match Fetcher.of_env env name with
           | _ -> "ok"
           | exception Invalid_argument message -> message))
  | _ -> None
