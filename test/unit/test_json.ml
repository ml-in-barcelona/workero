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

let json_text =
  Alcotest.testable
    (fun ppf j -> Format.pp_print_string ppf (Jsonkit.to_string j))
    (fun a b -> Jsonkit.to_string a = Jsonkit.to_string b)

let test_of_js () =
  Alcotest.check json_text "nested"
    (`Assoc
       [
         ("a", `Int 1);
         ("b", `List [ `String "x"; `Null; `Bool false; `Float 1.5 ]);
         ("c", `Assoc [ ("d", `String "h\u{e9}llo") ]);
       ])
    (Workero.JSON.of_js
       (Helpers.js_eval
          "({ a: 1, b: ['x', null, false, 1.5], c: { d: 'h\\u00e9llo' } })"));
  Alcotest.check json_text "undefined and function fields are dropped"
    (`Assoc [ ("a", `Int 1) ])
    (Workero.JSON.of_js (Helpers.js_eval "({ a: 1, b: undefined, c() {} })"));
  Alcotest.check json_text "date" (`String "1970-01-01T00:00:00.000Z")
    (Workero.JSON.of_js (Helpers.js_eval "new Date(0)"))

let test_of_js_without_json_form () =
  List.iter
    (fun src ->
      match Workero.JSON.of_js (Helpers.js_eval src) with
      | _ -> Alcotest.failf "%s: no exception" src
      | exception Invalid_argument _ -> ())
    [
      "undefined";
      "(function () {})";
      "Symbol('s')";
      "10n";
      "(() => { const o = {}; o.o = o; return o })()";
    ]

let test_to_js () =
  let v =
    Workero.JSON.to_js
      (`Assoc [ ("a", `Int 1); ("b", `List [ `String "x"; `Null ]) ])
  in
  Alcotest.(check string)
    "shape" "{\"a\":1,\"b\":[\"x\",null]}"
    (Js_of_ocaml.Js.to_string
       (Js_of_ocaml.Js.Unsafe.meth_call (Helpers.js_global "JSON") "stringify"
          [| v |]));
  Alcotest.(check bool) "a new object" true (Helpers.js_instance_of v "Object")

let test_to_js_non_finite () =
  List.iter
    (fun f ->
      match Workero.JSON.to_js (`List [ `Float f ]) with
      | _ -> Alcotest.failf "%g: no exception" f
      | exception Invalid_argument m ->
          Alcotest.(check bool)
            "message" true
            (String.starts_with ~prefix:"Workero.JSON.to_js: " m))
    [ Float.nan; Float.infinity; Float.neg_infinity ]

let test_round_trip () =
  let json =
    `Assoc
      [
        ("a", `List [ `Int 1; `Float 2.5; `String "\n\"x\""; `Null ]);
        ("b", `Assoc [ ("c", `Bool true) ]);
      ]
  in
  Alcotest.check json_text "round trip" json
    (Workero.JSON.of_js (Workero.JSON.to_js json))

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
      ( "js",
        [
          Alcotest.test_case "of_js" `Quick test_of_js;
          Alcotest.test_case "of_js without a json form" `Quick
            test_of_js_without_json_form;
          Alcotest.test_case "to_js" `Quick test_to_js;
          Alcotest.test_case "to_js of nan and infinity" `Quick
            test_to_js_non_finite;
          Alcotest.test_case "round trip" `Quick test_round_trip;
        ] );
    ]
