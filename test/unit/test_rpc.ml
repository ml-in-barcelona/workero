open Helpers
module Rpc = Workero.Rpc

let nested : Rpc.t =
  `Assoc
    [
      ("a", `List [ `Undefined; `Date 5.; `Bytes "\000\255" ]);
      ("b", `Map [ (`String "k", `Set [ `Bigint "1"; `Int 2 ]) ]);
      ("c", `Float 1.5);
      ("d", `Null);
    ]

let test_round_trip () =
  let cases : Rpc.t list =
    [
      `Undefined;
      `Null;
      `Bool false;
      `Int (-7);
      `Float 0.25;
      `String "x";
      `Bytes "";
      `Date 0.;
      `Bigint "-123456789012345678901234567890";
      `Map [ (`Int 1, `String "a") ];
      `Set [];
      nested;
    ]
  in
  List.iter
    (fun v -> Alcotest.(check bool) "same" true (Rpc.of_js (Rpc.to_js v) = v))
    cases

let kind v =
  Js_of_ocaml.Js.to_string
    (Js_of_ocaml.Js.typeof (Js_of_ocaml.Js.Unsafe.coerce v))

let tag v =
  Js_of_ocaml.Js.to_string
    (Js_of_ocaml.Js.Unsafe.meth_call
       (Js_of_ocaml.Js.Unsafe.get
          (Js_of_ocaml.Js.Unsafe.get
             (Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global "Object")
             "prototype")
          "toString")
       "call" [| v |])

let test_javascript_types () =
  Alcotest.(check string)
    "bytes" "[object Uint8Array]"
    (tag (Rpc.to_js (`Bytes "ab")));
  Alcotest.(check string) "date" "[object Date]" (tag (Rpc.to_js (`Date 1.)));
  Alcotest.(check string) "map" "[object Map]" (tag (Rpc.to_js (`Map [])));
  Alcotest.(check string) "set" "[object Set]" (tag (Rpc.to_js (`Set [])));
  Alcotest.(check string) "bigint" "bigint" (kind (Rpc.to_js (`Bigint "5")));
  Alcotest.(check string) "undefined" "undefined" (kind (Rpc.to_js `Undefined));
  Alcotest.(check string) "null" "object" (kind (Rpc.to_js `Null))

let test_numbers () =
  let read s = Rpc.of_js (js_eval s) in
  Alcotest.(check bool) "int" true (read "42" = `Int 42);
  Alcotest.(check bool) "float" true (read "1.5" = `Float 1.5);
  Alcotest.(check bool)
    "largest int" true
    (read (string_of_int max_int) = `Int max_int);
  Alcotest.(check bool) "huge" true (read "1e300" = `Float 1e300);
  Alcotest.(check bool)
    "negative zero" true
    (match read "-0" with `Float f -> 1. /. f < 0. | _ -> false);
  Alcotest.(check bool)
    "array buffer" true
    (read "new Uint8Array([7, 8]).buffer" = `Bytes "\007\008");
  Alcotest.(check bool)
    "view range" true
    (read "new Uint8Array([1, 2, 3, 4]).subarray(1, 3)" = `Bytes "\002\003")

let invalid name f =
  match f () with
  | _ -> Alcotest.failf "%s: did not raise" name
  | exception Invalid_argument _ -> ()

let test_unsupported () =
  invalid "typed array" (fun () -> Rpc.of_js (js_eval "new Float64Array(1)"));
  invalid "error" (fun () -> Rpc.of_js (js_eval "new Error('x')"));
  invalid "symbol" (fun () -> Rpc.of_js (js_eval "Symbol('s')"));
  invalid "class instance" (fun () -> Rpc.of_js (js_eval "new (class A {})()"));
  invalid "cycle" (fun () ->
      Rpc.of_js (js_eval "(() => { const a = []; a.push(a); return a; })()"));
  invalid "bigint text" (fun () -> Rpc.to_js (`Bigint "1.5"));
  invalid "bigint empty" (fun () -> Rpc.to_js (`Bigint ""))

let test_json () =
  let json : Jsonkit.t =
    `Assoc
      [ ("a", `List [ `Int 1; `String "x"; `Null; `Bool true; `Float 0.5 ]) ]
  in
  Alcotest.(check bool) "round trip" true (Rpc.to_json (Rpc.of_json json) = json);
  List.iter
    (fun v -> invalid "no json form" (fun () -> Rpc.to_json v))
    [
      `Undefined;
      `Bytes "";
      `Date 0.;
      `Bigint "1";
      `Map [];
      `Set [];
      `List [ `Date 0. ];
    ]

let values : Rpc.value list =
  [
    `Undefined;
    `Null;
    `Bool true;
    `Int 3;
    `Float 0.5;
    `String "s";
    `List [ `Date 1.; `Bytes "\000" ];
    `Assoc [ ("k", `Bigint "-9") ];
    `Bytes "ab";
    `Date 2.;
    `Bigint "12345678901234567890";
    `Map [ (`Set [ `Int 1 ], `List [ `Undefined ]) ];
    `Set [ `Map [ (`Int 1, `Date 0.) ] ];
  ]

let test_value_coercion () =
  let nested : Rpc.value =
    `Assoc
      [
        ("a", `List [ `Undefined; `Date 5.; `Bytes "\000\255" ]);
        ("b", `Map [ (`String "k", `Set [ `Bigint "1"; `Int 2 ]) ]);
      ]
  in
  let t : Rpc.t = (nested : Rpc.value :> Rpc.t) in
  Alcotest.(check bool) "survives JavaScript" true (Rpc.of_js (Rpc.to_js t) = t)

let test_to_value () =
  List.iter
    (fun v ->
      Alcotest.(check bool)
        "round trip" true
        (Rpc.to_value (v : Rpc.value :> Rpc.t) = v);
      Alcotest.(check bool)
        "through JavaScript" true
        (Rpc.to_value (Rpc.of_js (Rpc.to_js (v : Rpc.value :> Rpc.t))) = v))
    values

let test_to_value_unsupported () =
  let stub = Workero.Fetcher.of_js (js_eval "({})") in
  let _, stream = Workero.Stream.pipe () in
  List.iter
    (fun (name, v) -> invalid name (fun () -> Rpc.to_value v))
    [
      ("stream", `Stream stream);
      ("stub", `Stub stub);
      ("function", `Function (fun _ -> `Null));
      ("nested list", `List [ `Int 1; `Function (fun _ -> `Null) ]);
      ("nested assoc", `Assoc [ ("k", `Stub stub) ]);
      ("nested map key", `Map [ (`Stream stream, `Null) ]);
      ("nested map value", `Map [ (`Null, `Set [ `Stub stub ]) ]);
    ]

let () =
  Alcotest.run "workero.rpc"
    [
      ( "rpc",
        [
          Alcotest.test_case "values round-trip" `Quick test_round_trip;
          Alcotest.test_case "values have the JavaScript type" `Quick
            test_javascript_types;
          Alcotest.test_case "numbers and byte views" `Quick test_numbers;
          Alcotest.test_case "unsupported values raise" `Quick test_unsupported;
          Alcotest.test_case "JSON conversion" `Quick test_json;
          Alcotest.test_case "value coerces to t" `Quick test_value_coercion;
          Alcotest.test_case "to_value round-trips" `Quick test_to_value;
          Alcotest.test_case "to_value rejects non-values" `Quick
            test_to_value_unsupported;
        ] );
    ]
