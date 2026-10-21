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
        ] );
    ]
