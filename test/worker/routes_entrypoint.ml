open Workero
module E = Entrypoint

let int_arg = function `Int n -> n | _ -> invalid_arg "expected an int"

let rpc env ctx name args =
  match (name, args) with
  | "add", [ a; b ] -> `Int (int_arg a + int_arg b)
  | "add", _ -> invalid_arg "add takes two arguments"
  | "greet", [ `String who ] ->
      `String
        (Option.value (Env.var env "GREETING") ~default:"none" ^ ", " ^ who)
  | "greet", _ -> invalid_arg "greet takes a string"
  | "echo", args -> `List args
  | "nothing", _ -> `Null
  | "fail", _ -> failwith "calc failed"
  | "slow", _ ->
      Promise.await (Timer.sleep 20);
      `String "after await"
  | "background", _ ->
      Context.wait_until ctx (fun () -> Promise.await (Timer.sleep 5));
      `String "scheduled"
  | "ask_backend", _ ->
      let backend = Fetcher.of_env env "BACKEND" in
      `String (Response.body_text (Fetcher.fetch backend "http://b/x"))
  | other, _ -> invalid_arg ("no method " ^ other)

let () =
  E.register "Calc"
    ~rpc:
      [
        "add";
        "greet";
        "echo";
        "nothing";
        "fail";
        "slow";
        "background";
        "ask_backend";
      ] (fun env ctx ->
      E.make
        ~fetch:(fun req -> Response.text ("calc fetch " ^ Request.path req))
        ~rpc:(rpc env ctx) ());
  E.register "NoRpc" ~rpc:[ "declared" ] (fun _ _ -> E.make ());
  E.register "delete" ~rpc:[ "ping" ] (fun _ _ ->
      E.make ~rpc:(fun _ _ -> `String "pong") ())

let handle req env _ctx =
  let url = Request.url req in
  match URL.path url with
  | "/entrypoint/call" -> (
      let binding = Option.value (URL.query url "binding") ~default:"CALC" in
      let name = Option.value (URL.query url "method") ~default:"" in
      let args =
        match URL.query url "args" with
        | None -> []
        | Some s -> (
            match Jsonkit.of_string s with `List l -> l | j -> [ j ])
      in
      let stub = Fetcher.of_env env binding in
      match E.call stub name args with
      | result -> Some (Response.text (Jsonkit.to_string result))
      | exception Invalid_argument message ->
          Some (Response.text ("Invalid_argument " ^ message))
      | exception Js_error e ->
          Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e)))
  | _ -> None
