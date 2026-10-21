open Helpers

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

let test_response_empty () =
  let open Workero.Response in
  let r = empty 404 in
  Alcotest.(check int) "status" 404 (status r);
  Alcotest.(check (list (pair string string))) "no headers" [] (headers r);
  Alcotest.(check bool) "no body" true (body r = None);
  let r = empty ~headers:[ ("x-a", "1") ] 204 in
  Alcotest.(check int) "204" 204 (status r);
  Alcotest.(check (list (pair string string)))
    "headers"
    [ ("x-a", "1") ]
    (headers r)

let test_response_relative_redirect () =
  let open Workero.Response in
  let r = redirect "/login" in
  Alcotest.(check int) "default" 302 (status r);
  Alcotest.(check (option string))
    "location" (Some "/login") (header r "location");
  Alcotest.(check bool) "no body" true (body r = None);
  let r = redirect ~status:303 "/a?x=1" in
  Alcotest.(check int) "303" 303 (status r);
  Alcotest.(check (option string)) "query" (Some "/a?x=1") (header r "location");
  Alcotest.check_raises "bad status"
    (Invalid_argument "Workero.Response.redirect: status 200") (fun () ->
      ignore (redirect ~status:200 "/login"))

let test_response_copy () =
  let open Workero.Response in
  let r = redirect "http://a.test/x" in
  let c = copy ~headers:[ ("x-a", "1"); ("location", "http://a.test/y") ] r in
  Alcotest.(check int) "status kept" 302 (status c);
  Alcotest.(check (option string)) "new header" (Some "1") (header c "x-a");
  Alcotest.(check (option string))
    "location" (Some "http://a.test/y") (header c "location");
  let kept = copy r in
  Alcotest.(check (option string))
    "headers kept" (Some "http://a.test/x") (header kept "location");
  let c = copy ~status:307 r in
  Alcotest.(check int) "new status" 307 (status c)

let test_response_clone () =
  let open Workero.Response in
  let r = text ~status:201 ~headers:[ ("x-a", "1") ] "hi" in
  let c = clone r in
  Alcotest.(check bool) "new value" true (to_js c != to_js r);
  Alcotest.(check int) "status" 201 (status c);
  Alcotest.(check (list (pair string string))) "headers" (headers r) (headers c);
  Alcotest.(check bool) "body" true (body c <> None)

let test_response_header_all () =
  let open Workero.Response in
  let r =
    text
      ~headers:
        [
          ("set-cookie", "a=1");
          ("set-cookie", "b=2; Path=/");
          ("x-a", "1");
          ("x-a", "2");
        ]
      "x"
  in
  Alcotest.(check (list string))
    "set-cookie" [ "a=1"; "b=2; Path=/" ]
    (header_all r "Set-Cookie");
  Alcotest.(check (list string)) "joined" [ "1, 2" ] (header_all r "x-a");
  Alcotest.(check (list string)) "missing" [] (header_all r "x-none")

let test_response_of_stream () =
  let open Workero in
  let _writer, stream = Stream.pipe () in
  let r = Response.of_stream ~status:201 ~headers:[ ("x-a", "1") ] stream in
  Alcotest.(check int) "status" 201 (Response.status r);
  Alcotest.(check (option string)) "header" (Some "1") (Response.header r "x-a");
  Alcotest.(check bool) "body" true (Response.body r <> None);
  Alcotest.(check int)
    "default" 200
    (Response.status (Response.of_stream (snd (Stream.pipe ()))))

let () =
  Alcotest.run "workero.response"
    [
      ( "response",
        [
          Alcotest.test_case "text" `Quick test_response_text;
          Alcotest.test_case "html" `Quick test_response_html;
          Alcotest.test_case "make" `Quick test_response_make;
          Alcotest.test_case "redirect" `Quick test_response_redirect;
          Alcotest.test_case "null body status" `Quick
            test_response_null_body_status;
          Alcotest.test_case "empty" `Quick test_response_empty;
          Alcotest.test_case "relative redirect" `Quick
            test_response_relative_redirect;
          Alcotest.test_case "copy" `Quick test_response_copy;
          Alcotest.test_case "clone" `Quick test_response_clone;
          Alcotest.test_case "header_all" `Quick test_response_header_all;
          Alcotest.test_case "of_stream" `Quick test_response_of_stream;
        ] );
    ]
