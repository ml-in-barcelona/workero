open Helpers

let test_of_env () =
  let store = js_eval "({ get() {} })" in
  let env =
    Workero.Env.of_js (obj [| ("STORE", store); ("TEXT", jstr "plain") |])
  in
  ignore (Workero.Secret_store.of_env env "STORE");
  Alcotest.check_raises "missing"
    (Invalid_argument "Workero.Secret_store.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.Secret_store.of_env env "NOPE"));
  Alcotest.check_raises "a variable"
    (Invalid_argument
       "Workero.Secret_store.of_env: binding \"TEXT\" is a string, not a \
        Secrets Store secret") (fun () ->
      ignore (Workero.Secret_store.of_env env "TEXT"))

let () =
  Alcotest.run "workero.secret_store"
    [ ("secret_store", [ Alcotest.test_case "of_env" `Quick test_of_env ]) ]
