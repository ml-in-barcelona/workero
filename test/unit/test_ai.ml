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

let test_gateway () =
  let g =
    Workero.Ai.gateway "gw" ~cache_ttl:5
      ~retries:(Workero.Ai.retries ~backoff:`Linear ())
      ~metadata:[ ("a", `Int 1) ]
  in
  Alcotest.(check string)
    "fields"
    {|{"id":"gw","cacheTtl":5,"retries":{"backoff":"linear"},"metadata":{"a":1}}|}
    (Js_of_ocaml.Js.to_string
       (Js_of_ocaml.Js.Unsafe.fun_call
          (js_eval "(g => JSON.stringify(g))")
          [| inject g |]));
  Alcotest.check_raises "metadata"
    (Invalid_argument
       "Workero.Ai.gateway: a metadata value must be null, a boolean, a number \
        or a string") (fun () ->
      ignore (Workero.Ai.gateway "gw" ~metadata:[ ("a", `Assoc []) ]));
  Alcotest.check_raises "attempts"
    (Invalid_argument "Workero.Ai.retries: max_attempts 0 is outside 1 to 5")
    (fun () -> ignore (Workero.Ai.retries ~max_attempts:0 ()))

let () =
  Alcotest.run "workero.ai"
    [
      ( "ai",
        [
          Alcotest.test_case "of_env" `Quick test_of_env;
          Alcotest.test_case "gateway" `Quick test_gateway;
        ] );
    ]
