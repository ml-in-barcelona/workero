open Helpers

let test_of_env () =
  let env =
    Workero.Env.of_js
      (obj
         [|
           ("LIMITER", js_eval "({ limit() {} })");
           ("TEXT", jstr "plain");
           ("EMPTY", js_eval "({})");
         |])
  in
  ignore (Workero.Rate_limiter.of_env env "LIMITER");
  Alcotest.check_raises "missing"
    (Invalid_argument "Workero.Rate_limiter.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.Rate_limiter.of_env env "NOPE"));
  Alcotest.check_raises "a variable"
    (Invalid_argument
       "Workero.Rate_limiter.of_env: binding \"TEXT\" is a string, not a rate \
        limiter") (fun () -> ignore (Workero.Rate_limiter.of_env env "TEXT"));
  Alcotest.check_raises "no limit"
    (Invalid_argument
       "Workero.Rate_limiter.of_env: binding \"EMPTY\" is an object without \
        method limit, not a rate limiter") (fun () ->
      ignore (Workero.Rate_limiter.of_env env "EMPTY"))

let () =
  Alcotest.run "workero.rate_limiter"
    [ ("rate_limiter", [ Alcotest.test_case "of_env" `Quick test_of_env ]) ]
