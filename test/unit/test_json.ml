let status = Workero.Response.status
let header = Workero.Response.header
let json = `Assoc [ ("a", `Int 1) ]

let test_defaults () =
  let r = Workero.JSON.response json in
  Alcotest.(check int) "status" 200 (status r);
  Alcotest.(check (option string))
    "content-type" (Some "application/json; charset=utf-8")
    (header r "content-type")

let test_status_and_headers () =
  let r =
    Workero.JSON.response ~status:`Created ~headers:[ ("x-a", "b") ] json
  in
  Alcotest.(check int) "status" 201 (status r);
  Alcotest.(check (option string)) "x-a" (Some "b") (header r "x-a");
  Alcotest.(check (option string))
    "content-type" (Some "application/json; charset=utf-8")
    (header r "content-type")

let test_content_type_override () =
  let r =
    Workero.JSON.response
      ~headers:[ ("Content-Type", "application/vnd.api+json") ]
      json
  in
  Alcotest.(check (option string))
    "content-type" (Some "application/vnd.api+json") (header r "content-type")

let test_error () =
  let r = Workero.JSON.error "bad" in
  Alcotest.(check int) "default status" 400 (status r);
  Alcotest.(check (option string))
    "content-type" (Some "application/json; charset=utf-8")
    (header r "content-type");
  Alcotest.(check int)
    "custom status" 422
    (status (Workero.JSON.error ~status:(`Status 422) "x"))

let () =
  Alcotest.run "workero.json"
    [
      ( "response",
        [
          Alcotest.test_case "defaults" `Quick test_defaults;
          Alcotest.test_case "status and headers" `Quick test_status_and_headers;
          Alcotest.test_case "content-type override" `Quick
            test_content_type_override;
          Alcotest.test_case "error" `Quick test_error;
        ] );
    ]
