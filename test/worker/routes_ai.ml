open Workero

let handle req env _ctx =
  let url = Request.url req in
  let model = Option.value (URL.query url "model") ~default:"" in
  let ai () = Ai.of_env env "AI" in
  let input =
    `Assoc [ ("prompt", `String "hi"); ("n", `List [ `Int 1; `Null ]) ]
  in
  let failed f =
    match f () with
    | s -> s
    | exception Js_error e -> "js_error: " ^ Promise.error_to_string e
    | exception Invalid_argument message -> "invalid: " ^ message
  in
  match URL.path url with
  | "/ai/run" ->
      Some
        (Response.text
           (failed (fun () -> Jsonkit.to_string (Ai.run (ai ()) model input))))
  | "/ai/run-bytes" ->
      Some
        (Response.text
           (failed (fun () ->
                let bytes = Ai.run_bytes (ai ()) model input in
                String.concat ","
                  (List.init (String.length bytes) (fun i ->
                       string_of_int (Char.code bytes.[i]))))))
  | "/ai/shape" ->
      Some
        (Response.text
           (match Ai.of_env env model with
           | _ -> "ok"
           | exception Invalid_argument message -> message))
  | _ -> None
