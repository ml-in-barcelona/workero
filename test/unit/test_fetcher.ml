open Helpers

let test_of_env () =
  let fetcher = js_eval "({ fetch() {} })" in
  let env =
    Workero.Env.of_js
      (obj [| ("SVC", fetcher); ("KV", js_eval "({ get() {} })") |])
  in
  ignore (Workero.Fetcher.of_env env "SVC");
  Alcotest.check_raises "missing"
    (Invalid_argument "Workero.Fetcher.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.Fetcher.of_env env "NOPE"));
  Alcotest.check_raises "no fetch method"
    (Invalid_argument
       "Workero.Fetcher.of_env: binding \"KV\" is an object without method \
        fetch, not a service binding or an assets binding") (fun () ->
      ignore (Workero.Fetcher.of_env env "KV"))

let test_body_needs_a_method_with_body () =
  let fetcher = Workero.Fetcher.of_js (js_eval "({ fetch() {} })") in
  let message = "Workero.Fetcher.fetch: a GET or HEAD request has no body" in
  List.iter
    (fun m ->
      Alcotest.check_raises (Workero.Method.to_string m)
        (Invalid_argument message) (fun () ->
          ignore
            (Workero.Fetcher.fetch ~method_:m ~body:"x" fetcher "http://s/")))
    [ Workero.Method.GET; HEAD ];
  Alcotest.check_raises "default method" (Invalid_argument message) (fun () ->
      ignore (Workero.Fetcher.fetch ~body:"x" fetcher "http://s/"))

let () =
  Alcotest.run "workero.fetcher"
    [
      ( "fetcher",
        [
          Alcotest.test_case "of_env" `Quick test_of_env;
          Alcotest.test_case "body needs a method with body" `Quick
            test_body_needs_a_method_with_body;
        ] );
    ]
