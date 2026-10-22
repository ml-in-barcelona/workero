open Workero

let handle req env _ctx =
  let url = Request.url req in
  let dataset () = Analytics_engine.of_env env "ANALYTICS" in
  match URL.path url with
  | "/analytics/full" ->
      Analytics_engine.write ~index:"user-1" ~doubles:[ 1.5; 2.; -3. ]
        ~blobs:[ Text "page"; Bytes "\x00\xff\x80" ]
        (dataset ());
      Some (Response.text "written")
  | "/analytics/points" ->
      let binding = Js_of_ocaml.Js.Unsafe.get (Env.to_js env) "ANALYTICS" in
      let points =
        Promise.await
          (Promise.of_js ~decode:Decode.js
             (Js_of_ocaml.Js.Unsafe.meth_call binding "points" [||]))
      in
      Some (Response.text (Jsonkit.to_string (JSON.of_js points)))
  | "/analytics/empty" ->
      Analytics_engine.write (dataset ());
      Some (Response.text "written")
  | "/analytics/index-only" ->
      Analytics_engine.write ~index:"only" (dataset ());
      Some (Response.text "written")
  | "/analytics/raises" -> (
      match
        Analytics_engine.write ~blobs:[ Text "x" ]
          (Analytics_engine.of_env env "ANALYTICS_BROKEN")
      with
      | () -> Some (Response.text "unreachable")
      | exception Js_error e ->
          Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e)))
  | "/analytics/shape" ->
      let name = Option.value (URL.query url "name") ~default:"" in
      Some
        (Response.text
           (match Analytics_engine.of_env env name with
           | _ -> "ok"
           | exception Invalid_argument message -> message))
  | _ -> None
