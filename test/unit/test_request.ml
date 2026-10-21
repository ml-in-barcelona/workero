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

let test_request_path () =
  let open Workero.Request in
  Alcotest.(check string)
    "raw path" "/p/a%2Fb/%E2%9C%93"
    (path (request "http://a.test/p/a%2Fb/%E2%9C%93?x=1"));
  Alcotest.(check string) "root" "/" (path (request "http://a.test"))

let test_request_query_string () =
  let open Workero.Request in
  Alcotest.(check string)
    "query" "a=1%2B2&b"
    (query_string (request "http://a.test/p?a=1%2B2&b"));
  Alcotest.(check string) "none" "" (query_string (request "http://a.test/p"));
  Alcotest.(check string) "empty" "" (query_string (request "http://a.test/p?"))

let test_request_header_all () =
  let open Workero.Request in
  let multi = js_new "Headers" [] in
  ignore
    (Js_of_ocaml.Js.Unsafe.meth_call multi "append" [| jstr "x-m"; jstr "1" |]);
  ignore
    (Js_of_ocaml.Js.Unsafe.meth_call multi "append" [| jstr "X-M"; jstr "2" |]);
  let req = request ~init:[ ("headers", multi) ] "http://a.test/" in
  Alcotest.(check (list string)) "joined" [ "1, 2" ] (header_all req "x-M");
  let cookie =
    request
      ~init:[ ("headers", obj [| ("cookie", jstr "a=1; b=2") |]) ]
      "http://a.test/"
  in
  Alcotest.(check (list string))
    "cookie" [ "a=1; b=2" ]
    (header_all cookie "cookie");
  Alcotest.(check (list string)) "missing" [] (header_all req "x-none")

let test_request_body () =
  let open Workero.Request in
  Alcotest.(check bool)
    "GET has none" true
    (body (request "http://a.test/") = None);
  let post =
    request
      ~init:[ ("method", jstr "POST"); ("body", jstr "x") ]
      "http://a.test/"
  in
  Alcotest.(check bool) "POST has one" true (body post <> None)

let test_request_clone () =
  let open Workero.Request in
  let req =
    request
      ~init:
        [
          ("method", jstr "POST");
          ("body", jstr "x");
          ("headers", obj [| ("x-a", jstr "1") |]);
        ]
      "http://a.test/p?q=1"
  in
  let copy = clone req in
  Alcotest.(check bool) "new value" true (to_js copy != to_js req);
  Alcotest.check method_t "method" Workero.Method.POST (method_ copy);
  Alcotest.(check string) "path" "/p" (path copy);
  Alcotest.(check (option string)) "header" (Some "1") (header copy "x-a");
  Alcotest.(check bool) "body still there" true (body req <> None)

let () =
  Alcotest.run "workero.request"
    [
      ( "request",
        [
          Alcotest.test_case "method" `Quick test_request_method;
          Alcotest.test_case "headers" `Quick test_request_headers;
          Alcotest.test_case "cf" `Quick test_request_cf;
          Alcotest.test_case "path" `Quick test_request_path;
          Alcotest.test_case "query_string" `Quick test_request_query_string;
          Alcotest.test_case "header_all" `Quick test_request_header_all;
          Alcotest.test_case "body" `Quick test_request_body;
          Alcotest.test_case "clone" `Quick test_request_clone;
        ] );
    ]
