let test_fetch_body_needs_a_method_with_body () =
  List.iter
    (fun m ->
      Alcotest.check_raises (Workero.Method.to_string m)
        (Invalid_argument "Workero.fetch: a GET or HEAD request has no body")
        (fun () -> ignore (Workero.fetch ~method_:m ~body:"x" "http://a.test/")))
    [ Workero.Method.GET; HEAD ];
  Alcotest.check_raises "default method"
    (Invalid_argument "Workero.fetch: a GET or HEAD request has no body")
    (fun () -> ignore (Workero.fetch ~body:"x" "http://a.test/"))

let () =
  Alcotest.run "workero.fetch"
    [
      ( "fetch",
        [
          Alcotest.test_case "body needs a method with body" `Quick
            test_fetch_body_needs_a_method_with_body;
        ] );
    ]
