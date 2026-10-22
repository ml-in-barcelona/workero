open Helpers

let test_of_env () =
  let env =
    Workero.Env.of_js
      (obj [| ("AI", js_eval "({ run() {} })"); ("TEXT", jstr "plain") |])
  in
  ignore (Workero.Ai.of_env env "AI");
  Alcotest.check_raises "missing"
    (Invalid_argument "Workero.Ai.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.Ai.of_env env "NOPE"));
  Alcotest.check_raises "a variable"
    (Invalid_argument
       "Workero.Ai.of_env: binding \"TEXT\" is a string, not a Workers AI \
        binding") (fun () -> ignore (Workero.Ai.of_env env "TEXT"))

let () =
  Alcotest.run "workero.ai"
    [ ("ai", [ Alcotest.test_case "of_env" `Quick test_of_env ]) ]
