let url_of s =
  match Workero.URL.of_string s with
  | Some u -> u
  | None -> Alcotest.failf "not a URL: %s" s

let test_url_parts () =
  let u = url_of "https://example.com:8443/a/b?x=1&y=2#frag" in
  Alcotest.(check string) "scheme" "https" (Workero.URL.scheme u);
  Alcotest.(check string) "host" "example.com" (Workero.URL.host u);
  Alcotest.(check int) "port" 8443 (Workero.URL.port u);
  Alcotest.(check string) "path" "/a/b" (Workero.URL.path u)

let test_url_default_port () =
  Alcotest.(check int) "http" 80 (Workero.URL.port (url_of "http://a.test/"));
  Alcotest.(check int) "https" 443 (Workero.URL.port (url_of "https://a.test/"))

let test_url_query () =
  let u = url_of "http://a.test/?k=1&k=2&q=a+b%20c" in
  Alcotest.(check (option string)) "first" (Some "1") (Workero.URL.query u "k");
  Alcotest.(check (list string))
    "all" [ "1"; "2" ]
    (Workero.URL.query_all u "k");
  Alcotest.(check (option string))
    "decoded" (Some "a b c") (Workero.URL.query u "q");
  Alcotest.(check (option string)) "missing" None (Workero.URL.query u "z")

let test_url_rejects () =
  Alcotest.(check bool) "not a URL" true (Workero.URL.of_string "nope" = None);
  Alcotest.(check bool) "ftp" true (Workero.URL.of_string "ftp://a.test/" = None)

let js_global name = Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global name

let js_new name args =
  Js_of_ocaml.Js.Unsafe.new_obj (js_global name) (Array.of_list args)

let inject = Js_of_ocaml.Js.Unsafe.inject
let jstr s = inject (Js_of_ocaml.Js.string s)
let obj = Js_of_ocaml.Js.Unsafe.obj

let request ?(init = []) url =
  Workero.Request.of_js
    (js_new "Request" [ jstr url; obj (Array.of_list init) ])

let method_t =
  Alcotest.testable
    (fun ppf m -> Format.pp_print_string ppf (Workero.Method.to_string m))
    ( = )

let test_method_round_trip () =
  let open Workero.Method in
  List.iter
    (fun m -> Alcotest.check method_t (to_string m) m (of_string (to_string m)))
    [ GET; HEAD; POST; PUT; DELETE; PATCH; OPTIONS; Other "PURGE" ]

let test_method_names () =
  let open Workero.Method in
  Alcotest.(check string) "post" "POST" (to_string POST);
  Alcotest.check method_t "custom" (Other "PURGE") (of_string "PURGE");
  Alcotest.check method_t "case-sensitive" (Other "get") (of_string "get")

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

let test_response_text () =
  let open Workero.Response in
  let r = text ~status:201 ~headers:[ ("x-a", "1"); ("x-a", "2") ] "hi" in
  Alcotest.(check int) "status" 201 (status r);
  Alcotest.(check (option string)) "repeated" (Some "1, 2") (header r "x-a");
  Alcotest.(check (option string))
    "content-type" (Some "text/plain;charset=UTF-8") (header r "content-type");
  Alcotest.(check int) "default status" 200 (status (text "x"))

let test_response_html () =
  let open Workero.Response in
  Alcotest.(check (option string))
    "default" (Some "text/html; charset=utf-8")
    (header (html "<p>") "content-type");
  let given =
    html ~headers:[ ("Content-Type", "text/html; charset=latin1") ] "<p>"
  in
  Alcotest.(check (list (pair string string)))
    "given wins"
    [ ("content-type", "text/html; charset=latin1") ]
    (headers given)

let test_response_make () =
  let open Workero.Response in
  let r = make ~status:202 "\000\255" in
  Alcotest.(check int) "status" 202 (status r);
  Alcotest.(check (option string))
    "no content-type" None (header r "content-type")

let test_response_redirect () =
  let open Workero.Response in
  let r = redirect "http://a.test/x" in
  Alcotest.(check int) "default" 302 (status r);
  Alcotest.(check (option string))
    "location" (Some "http://a.test/x") (header r "location");
  Alcotest.(check int)
    "301" 301
    (status (redirect ~status:301 "http://a.test/"));
  Alcotest.check_raises "bad status"
    (Invalid_argument "Workero.Response.redirect: status 200") (fun () ->
      ignore (redirect ~status:200 "http://a.test/"))

let test_response_null_body_status () =
  let open Workero.Response in
  List.iter
    (fun code ->
      Alcotest.(check int)
        (string_of_int code) code
        (status (text ~status:code "")))
    [ 204; 205; 304 ];
  Alcotest.(check int) "make" 204 (status (make ~status:204 ""))

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

let test_url_unsupported () =
  Alcotest.(check bool)
    "underscore host" true
    (Workero.URL.of_string "http://a_b.test/" = None);
  Alcotest.(check bool)
    "userinfo" true
    (Workero.URL.of_string "http://user:pw@a.test/" = None)

let test_env_var () =
  let env = Workero.Env.of_js (obj [| ("A", jstr "x"); ("B", inject 1) |]) in
  Alcotest.(check (option string)) "string" (Some "x") (Workero.Env.var env "A");
  Alcotest.(check (option string)) "not a string" None (Workero.Env.var env "B");
  Alcotest.(check (option string)) "missing" None (Workero.Env.var env "C")

let test_scheduled () =
  let c =
    Workero.Scheduled.of_js
      (obj [| ("cron", jstr "*/5 * * * *"); ("scheduledTime", inject 1.7e12) |])
  in
  Alcotest.(check string) "cron" "*/5 * * * *" (Workero.Scheduled.cron c);
  Alcotest.(check (float 0.)) "time" 1.7e12 (Workero.Scheduled.scheduled_time c);
  let empty = Workero.Scheduled.of_js (obj [||]) in
  Alcotest.(check string) "no cron" "" (Workero.Scheduled.cron empty);
  Alcotest.(check (float 0.))
    "no time" 0.
    (Workero.Scheduled.scheduled_time empty)

let () =
  Alcotest.run "workero"
    [
      ( "url",
        [
          Alcotest.test_case "parts" `Quick test_url_parts;
          Alcotest.test_case "default port" `Quick test_url_default_port;
          Alcotest.test_case "query" `Quick test_url_query;
          Alcotest.test_case "rejects" `Quick test_url_rejects;
          Alcotest.test_case "unsupported" `Quick test_url_unsupported;
        ] );
      ( "method",
        [
          Alcotest.test_case "round trip" `Quick test_method_round_trip;
          Alcotest.test_case "names" `Quick test_method_names;
        ] );
      ( "request",
        [
          Alcotest.test_case "method" `Quick test_request_method;
          Alcotest.test_case "headers" `Quick test_request_headers;
          Alcotest.test_case "cf" `Quick test_request_cf;
        ] );
      ( "response",
        [
          Alcotest.test_case "text" `Quick test_response_text;
          Alcotest.test_case "html" `Quick test_response_html;
          Alcotest.test_case "make" `Quick test_response_make;
          Alcotest.test_case "redirect" `Quick test_response_redirect;
          Alcotest.test_case "null body status" `Quick
            test_response_null_body_status;
        ] );
      ( "fetch",
        [
          Alcotest.test_case "body needs a method with body" `Quick
            test_fetch_body_needs_a_method_with_body;
        ] );
      ("env", [ Alcotest.test_case "var" `Quick test_env_var ]);
      ("scheduled", [ Alcotest.test_case "fields" `Quick test_scheduled ]);
    ]
