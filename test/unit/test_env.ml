open Helpers

let test_env_var () =
  let env = Workero.Env.of_js (obj [| ("A", jstr "x"); ("B", inject 1) |]) in
  Alcotest.(check (option string)) "string" (Some "x") (Workero.Env.var env "A");
  Alcotest.(check (option string)) "not a string" None (Workero.Env.var env "B");
  Alcotest.(check (option string)) "missing" None (Workero.Env.var env "C")

let () =
  Alcotest.run "workero.env"
    [ ("env", [ Alcotest.test_case "var" `Quick test_env_var ]) ]
