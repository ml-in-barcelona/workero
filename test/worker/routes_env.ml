open Workero

let opt = Option.value ~default:"none"

let invalid f =
  match f () with
  | s -> s
  | exception Invalid_argument message -> "invalid: " ^ message

let handle req env _ctx =
  let url = Request.url req in
  let name = Option.value (URL.query url "name") ~default:"" in
  match URL.path url with
  | "/env/secret" ->
      Some (Response.text (invalid (fun () -> Env.secret env name)))
  | "/env/json" ->
      Some
        (Response.text
           (invalid (fun () ->
                opt (Option.map Jsonkit.to_string (Env.json env name)))))
  | "/secret-store/get" ->
      let store = Secret_store.of_env env name in
      Some
        (match Secret_store.get store with
        | value -> Response.text (opt value)
        | exception Js_error e ->
            Response.text ~status:`Bad_Gateway (Promise.error_to_string e))
  | "/secret-store/shape" ->
      Some
        (Response.text
           (invalid (fun () ->
                ignore (Secret_store.of_env env name);
                "ok")))
  | _ -> None
