open Workero

let handle req env _ctx =
  let url = Request.url req in
  let key = Option.value (URL.query url "key") ~default:"" in
  match URL.path url with
  | "/rate-limiter/limit" ->
      let limiter = Rate_limiter.of_env env "LIMITER" in
      let results =
        List.init 3 (fun _ -> string_of_bool (Rate_limiter.limit limiter key))
      in
      Some (Response.text (String.concat "," results))
  | "/rate-limiter/raises" -> (
      let limiter = Rate_limiter.of_env env "LIMITER" in
      match Rate_limiter.limit limiter "throw" with
      | _ -> Some (Response.text "unreachable")
      | exception Js_error e ->
          Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e)))
  | "/rate-limiter/shape" ->
      Some
        (Response.text
           (match Rate_limiter.of_env env key with
           | _ -> "ok"
           | exception Invalid_argument message -> message))
  | _ -> None
