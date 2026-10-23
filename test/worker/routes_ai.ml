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
  let gateway =
    Ai.gateway "my-gateway" ~cache_key:"k" ~cache_ttl:60 ~skip_cache:false
      ~collect_log:true ~event_id:"e1" ~request_timeout_ms:5000
      ~retries:
        (Ai.retries ~max_attempts:3 ~retry_delay_ms:100 ~backoff:`Exponential ())
      ~metadata:
        [
          ("user", `String "u1");
          ("n", `Int 2);
          ("ok", `Bool true);
          ("none", `Null);
        ]
  in
  let read_stream s =
    let chunks = ref [] in
    Stream.iter (fun chunk -> chunks := chunk :: !chunks) s;
    String.concat "" (List.rev !chunks)
  in
  match URL.path url with
  | "/ai/run-gateway" ->
      Some
        (Response.text
           (failed (fun () ->
                Jsonkit.to_string (Ai.run ~gateway (ai ()) model input))))
  | "/ai/run-gateway-id" ->
      Some
        (Response.text
           (failed (fun () ->
                Jsonkit.to_string
                  (Ai.run ~gateway:(Ai.gateway "plain") (ai ()) model input))))
  | "/ai/run-stream" ->
      Some
        (Response.text
           (failed (fun () -> read_stream (Ai.run_stream (ai ()) model input))))
  | "/ai/run-stream-gateway" ->
      Some
        (Response.text
           (failed (fun () ->
                read_stream (Ai.run_stream ~gateway (ai ()) model input))))
  | "/ai/run-stream-replace" ->
      Some
        (Response.text
           (failed (fun () ->
                read_stream
                  (Ai.run_stream (ai ()) model
                     (`Assoc [ ("stream", `Bool false); ("p", `Int 1) ])))))
  | "/ai/run-stream-bad-input" ->
      Some
        (Response.text
           (failed (fun () ->
                read_stream (Ai.run_stream (ai ()) model (`String "x")))))
  | "/ai/bad-options" ->
      Some
        (Response.text
           (String.concat "\n"
              [
                failed (fun () ->
                    ignore (Ai.gateway "g" ~metadata:[ ("k", `List []) ]);
                    "no error");
                failed (fun () ->
                    ignore (Ai.retries ~max_attempts:6 ());
                    "no error");
              ]))
  | "/ai/run-bytes-gateway" ->
      Some
        (Response.text
           (failed (fun () ->
                string_of_int
                  (String.length
                     (Ai.run_bytes ~gateway:(Ai.gateway "g") (ai ()) model input)))))
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
