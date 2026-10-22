open Workero

let handle req env _ctx =
  let url = Request.url req in
  let name = Option.value (URL.query url "name") ~default:"HYPERDRIVE" in
  match URL.path url with
  | "/hyperdrive/details" ->
      let db = Hyperdrive.of_env env name in
      Some
        (Response.text
           (String.concat "\n"
              [
                "user=" ^ Hyperdrive.user db;
                "database=" ^ Hyperdrive.database db;
                "port=" ^ string_of_int (Hyperdrive.port db);
                "host=" ^ Hyperdrive.host db;
                "password=" ^ Hyperdrive.password db;
                "connection_string=" ^ Hyperdrive.connection_string db;
              ]))
  | "/hyperdrive/bad-fields" ->
      let db = Hyperdrive.of_env env "HYPERDRIVE_BAD" in
      let attempt f =
        match f db with
        | _ -> "unreachable"
        | exception Invalid_argument message -> message
      in
      Some
        (Response.text
           (String.concat "\n"
              [
                attempt Hyperdrive.connection_string;
                attempt (fun db -> string_of_int (Hyperdrive.port db));
                attempt Hyperdrive.password;
              ]))
  | "/hyperdrive/shape" ->
      Some
        (Response.text
           (match Hyperdrive.of_env env name with
           | _ -> "ok"
           | exception Invalid_argument message -> message))
  | _ -> None
