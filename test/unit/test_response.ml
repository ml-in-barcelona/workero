open Helpers

let test_response_text () =
  let open Workero.Response in
  let r = text ~status:`Created ~headers:[ ("x-a", "1"); ("x-a", "2") ] "hi" in
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
  let r = make ~status:`Accepted "\000\255" in
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
    (status (redirect ~status:`Moved_Permanently "http://a.test/"))

let test_response_null_body_status () =
  let open Workero.Response in
  List.iter
    (fun code ->
      Alcotest.(check int)
        (string_of_int code) code
        (status (text ~status:(`Status code) "")))
    [ 204; 205; 304 ];
  Alcotest.(check int) "make" 204 (status (make ~status:(`Status 204) ""))

let test_response_status_with_body () =
  let open Workero.Response in
  List.iter
    (fun code ->
      Alcotest.check_raises (string_of_int code)
        (Invalid_argument
           (Printf.sprintf "Workero.Response: status %d allows no body" code))
        (fun () -> ignore (text ~status:(`Status code) "x")))
    [ 204; 205; 304 ];
  Alcotest.check_raises "make"
    (Invalid_argument "Workero.Response: status 204 allows no body") (fun () ->
      ignore (make ~status:(`Status 204) "x"));
  Alcotest.check_raises "html"
    (Invalid_argument "Workero.Response: status 304 allows no body") (fun () ->
      ignore (html ~status:(`Status 304) "x"));
  Alcotest.check_raises "of_stream"
    (Invalid_argument "Workero.Response: status 205 allows no body") (fun () ->
      ignore (of_stream ~status:(`Status 205) (snd (Workero.Stream.pipe ()))))

let test_response_status_range () =
  let open Workero.Response in
  List.iter
    (fun code ->
      Alcotest.check_raises (string_of_int code)
        (Invalid_argument
           (Printf.sprintf "Workero.Response: status %d is outside 200..599"
              code))
        (fun () -> ignore (text ~status:(`Status code) "x")))
    [ 0; 99; 100; 101; 199; 600 ];
  Alcotest.check_raises "empty 101"
    (Invalid_argument "Workero.Response: status 101 is outside 200..599")
    (fun () -> ignore (empty (`Status 101)));
  Alcotest.(check int) "200" 200 (status (text ~status:(`Status 200) "x"));
  Alcotest.(check int) "599" 599 (status (text ~status:(`Status 599) "x"));
  Alcotest.(check int) "418" 418 (status (text ~status:(`Status 418) "x"))

let test_response_empty () =
  let open Workero.Response in
  let r = empty `Not_Found in
  Alcotest.(check int) "status" 404 (status r);
  Alcotest.(check (list (pair string string))) "no headers" [] (headers r);
  Alcotest.(check bool) "no body" true (body r = None);
  let r = empty ~headers:[ ("x-a", "1") ] `No_Content in
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
  let r = redirect ~status:`See_Other "/a?x=1" in
  Alcotest.(check int) "303" 303 (status r);
  Alcotest.(check (option string)) "query" (Some "/a?x=1") (header r "location")

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
  let c = copy ~status:`Temporary_Redirect r in
  Alcotest.(check int) "new status" 307 (status c)

let test_response_clone () =
  let open Workero.Response in
  let r = text ~status:`Created ~headers:[ ("x-a", "1") ] "hi" in
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
  let r =
    Response.of_stream ~status:`Created ~headers:[ ("x-a", "1") ] stream
  in
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
          Alcotest.test_case "no-body status with a body" `Quick
            test_response_status_with_body;
          Alcotest.test_case "status range" `Quick test_response_status_range;
          Alcotest.test_case "empty" `Quick test_response_empty;
          Alcotest.test_case "relative redirect" `Quick
            test_response_relative_redirect;
          Alcotest.test_case "copy" `Quick test_response_copy;
          Alcotest.test_case "clone" `Quick test_response_clone;
          Alcotest.test_case "header_all" `Quick test_response_header_all;
          Alcotest.test_case "of_stream" `Quick test_response_of_stream;
        ] );
    ]
