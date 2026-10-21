let all : (Workero.Status.t * int) list =
  [
    (`Continue, 100);
    (`Switching_Protocols, 101);
    (`OK, 200);
    (`Created, 201);
    (`Accepted, 202);
    (`Non_Authoritative_Information, 203);
    (`No_Content, 204);
    (`Reset_Content, 205);
    (`Partial_Content, 206);
    (`Multiple_Choices, 300);
    (`Moved_Permanently, 301);
    (`Found, 302);
    (`See_Other, 303);
    (`Not_Modified, 304);
    (`Temporary_Redirect, 307);
    (`Permanent_Redirect, 308);
    (`Bad_Request, 400);
    (`Unauthorized, 401);
    (`Payment_Required, 402);
    (`Forbidden, 403);
    (`Not_Found, 404);
    (`Method_Not_Allowed, 405);
    (`Not_Acceptable, 406);
    (`Proxy_Authentication_Required, 407);
    (`Request_Timeout, 408);
    (`Conflict, 409);
    (`Gone, 410);
    (`Length_Required, 411);
    (`Precondition_Failed, 412);
    (`Payload_Too_Large, 413);
    (`URI_Too_Long, 414);
    (`Unsupported_Media_Type, 415);
    (`Range_Not_Satisfiable, 416);
    (`Expectation_Failed, 417);
    (`Misdirected_Request, 421);
    (`Too_Early, 425);
    (`Upgrade_Required, 426);
    (`Precondition_Required, 428);
    (`Too_Many_Requests, 429);
    (`Request_Header_Fields_Too_Large, 431);
    (`Unavailable_For_Legal_Reasons, 451);
    (`Internal_Server_Error, 500);
    (`Not_Implemented, 501);
    (`Bad_Gateway, 502);
    (`Service_Unavailable, 503);
    (`Gateway_Timeout, 504);
    (`HTTP_Version_Not_Supported, 505);
  ]

let test_to_int () =
  List.iter
    (fun (tag, code) ->
      Alcotest.(check int) (string_of_int code) code (Workero.Status.to_int tag))
    all

let test_of_int () =
  List.iter
    (fun (tag, code) ->
      Alcotest.(check bool)
        (string_of_int code) true
        (Workero.Status.of_int code = tag))
    all;
  Alcotest.(check bool) "unknown" true (Workero.Status.of_int 418 = `Status 418);
  Alcotest.(check int) "to_int Status" 418 (Workero.Status.to_int (`Status 418))

let test_round_trip () =
  List.iter
    (fun (tag, _) ->
      Alcotest.(check bool)
        "tag" true
        (Workero.Status.of_int (Workero.Status.to_int tag) = tag))
    all;
  for code = 0 to 999 do
    Alcotest.(check int)
      (string_of_int code) code
      (Workero.Status.to_int (Workero.Status.of_int code))
  done

let test_to_string () =
  Alcotest.(check string)
    "404" "Not Found"
    (Workero.Status.to_string `Not_Found);
  Alcotest.(check string) "200" "OK" (Workero.Status.to_string `OK);
  Alcotest.(check string)
    "Status 404" "Not Found"
    (Workero.Status.to_string (`Status 404));
  Alcotest.(check string)
    "unknown" "418"
    (Workero.Status.to_string (`Status 418));
  List.iter
    (fun (tag, code) ->
      Alcotest.(check bool)
        (string_of_int code) true
        (Workero.Status.to_string tag <> ""))
    all

let test_empty_no_content () =
  let r = Workero.Response.empty `No_Content in
  Alcotest.(check int) "status" 204 (Workero.Response.status r);
  Alcotest.(check bool) "no body" true (Workero.Response.body r = None)

let () =
  Alcotest.run "status"
    [
      ( "status",
        [
          Alcotest.test_case "to_int" `Quick test_to_int;
          Alcotest.test_case "of_int" `Quick test_of_int;
          Alcotest.test_case "round trip" `Quick test_round_trip;
          Alcotest.test_case "to_string" `Quick test_to_string;
          Alcotest.test_case "empty No_Content" `Quick test_empty_no_content;
        ] );
    ]
