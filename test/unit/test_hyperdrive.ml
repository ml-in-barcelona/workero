open Helpers

let binding =
  js_eval
    "({ connectionString: 'postgres://u:p@h:1/d', host: 'h', port: 1, user: \
     'u', password: 'p', database: 'd', connect() {} })"

let env_of fields = Workero.Env.of_js (obj (Array.of_list fields))

let test_fields () =
  let db = Workero.Hyperdrive.of_env (env_of [ ("DB", binding) ]) "DB" in
  let open Workero.Hyperdrive in
  Alcotest.(check string)
    "connection_string" "postgres://u:p@h:1/d" (connection_string db);
  Alcotest.(check string) "host" "h" (host db);
  Alcotest.(check int) "port" 1 (port db);
  Alcotest.(check string) "user" "u" (user db);
  Alcotest.(check string) "password" "p" (password db);
  Alcotest.(check string) "database" "d" (database db)

let test_of_env () =
  let env = env_of [ ("DB", binding); ("TEXT", jstr "plain") ] in
  Alcotest.check_raises "missing"
    (Invalid_argument "Workero.Hyperdrive.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.Hyperdrive.of_env env "NOPE"));
  Alcotest.check_raises "a variable"
    (Invalid_argument
       "Workero.Hyperdrive.of_env: binding \"TEXT\" is a string, not a \
        Hyperdrive binding") (fun () ->
      ignore (Workero.Hyperdrive.of_env env "TEXT"))

let test_secret_not_in_error () =
  let bad = js_eval "({ password: 12345, port: 'secret-port' })" in
  let db = Workero.Hyperdrive.of_env (env_of [ ("DB", bad) ]) "DB" in
  let message f =
    match f () with
    | _ -> Alcotest.fail "no exception"
    | exception Invalid_argument m -> m
  in
  Alcotest.(check string)
    "password" "Workero.Decode: expected string, got number"
    (message (fun () -> Workero.Hyperdrive.password db));
  Alcotest.(check string)
    "port" "Workero.Decode: expected number, got string"
    (message (fun () -> string_of_int (Workero.Hyperdrive.port db)))

let () =
  Alcotest.run "workero.hyperdrive"
    [
      ( "hyperdrive",
        [
          Alcotest.test_case "fields" `Quick test_fields;
          Alcotest.test_case "of_env" `Quick test_of_env;
          Alcotest.test_case "no value in errors" `Quick
            test_secret_not_in_error;
        ] );
    ]
