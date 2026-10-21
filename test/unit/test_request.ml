open Helpers

let test_request_method () =
  let req =
    request
      ~init:[ ("method", jstr "PATCH"); ("body", jstr "x") ]
      "http://a.test/"
  in
  Alcotest.check method_t "method" Workero.Method.PATCH
    (Workero.Request.method_ req);
  Alcotest.check method_t "default" Workero.Method.GET
    (Workero.Request.method_ (request "http://a.test/"))

let test_request_headers () =
  let headers = obj [| ("X-B", jstr "2"); ("x-a", jstr "1") |] in
  let req = request ~init:[ ("headers", headers) ] "http://a.test/" in
  Alcotest.(check (option string))
    "header" (Some "2")
    (Workero.Request.header req "x-b");
  Alcotest.(check (option string))
    "missing" None
    (Workero.Request.header req "x-c");
  Alcotest.(check (list (pair string string)))
    "headers"
    [ ("x-a", "1"); ("x-b", "2") ]
    (Workero.Request.headers req)

let test_request_cf () =
  let open Workero in
  let absent = Request.cf (request "http://a.test/") in
  Alcotest.(check (option string)) "no country" None (Cf.country absent);
  Alcotest.(check (option int)) "no asn" None (Cf.asn absent);
  let cf =
    obj [| ("country", jstr "ES"); ("colo", jstr "BCN"); ("asn", inject 1234) |]
  in
  let req = Request.of_js (obj [| ("cf", cf) |]) in
  let cf = Request.cf req in
  Alcotest.(check (option string)) "country" (Some "ES") (Cf.country cf);
  Alcotest.(check (option string)) "colo" (Some "BCN") (Cf.colo cf);
  Alcotest.(check (option int)) "asn" (Some 1234) (Cf.asn cf);
  Alcotest.(check (option string)) "city" None (Cf.city cf)

let () =
  Alcotest.run "workero.request"
    [
      ( "request",
        [
          Alcotest.test_case "method" `Quick test_request_method;
          Alcotest.test_case "headers" `Quick test_request_headers;
          Alcotest.test_case "cf" `Quick test_request_cf;
        ] );
    ]
