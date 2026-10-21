open Helpers

let value =
  Alcotest.testable
    (fun ppf (v : Workero.Sql_value.t) ->
      match v with
      | Null -> Format.pp_print_string ppf "Null"
      | Int n -> Format.fprintf ppf "Int %Ld" n
      | Float f -> Format.fprintf ppf "Float %g" f
      | Text s -> Format.fprintf ppf "Text %S" s
      | Blob s -> Format.fprintf ppf "Blob %S" s)
    ( = )

let test_sql_value_of_js () =
  let open Workero.Sql_value in
  List.iter
    (fun (src, expected) ->
      Alcotest.check value src expected (of_js (js_eval src)))
    [
      ("null", Null);
      ("undefined", Null);
      ("42", Int 42L);
      ("-5", Int (-5L));
      ("3000000000", Int 3_000_000_000L);
      ("9007199254740992", Int 9_007_199_254_740_992L);
      ("1.5", Float 1.5);
      ("1e300", Float 1e300);
      ("'h\\u00e9'", Text "h\xc3\xa9");
      ("9223372036854775807n", Int Int64.max_int);
      ("-9223372036854775808n", Int Int64.min_int);
      ("new Uint8Array([0, 255, 10]).buffer", Blob "\000\255\n");
      ("new Uint8Array([0, 255, 10])", Blob "\000\255\n");
      ("[0, 255, 10]", Blob "\000\255\n");
    ]

let test_sql_value_to_js () =
  let open Workero.Sql_value in
  List.iter
    (fun v -> Alcotest.check value "round trip" v (of_js (to_js v)))
    [
      Null;
      Int 3_000_000_000L;
      Int (-9_007_199_254_740_992L);
      Float 2.5;
      Text "x";
      Blob "\255\000\128";
    ];
  Alcotest.check_raises "beyond 2^53"
    (Invalid_argument "Workero.Sql_value.to_js: 9007199254740993 is beyond 2^53")
    (fun () -> ignore (to_js (Int 9_007_199_254_740_993L)))

let test_sql_value_rejects () =
  let open Workero.Sql_value in
  List.iter
    (fun (src, message) ->
      Alcotest.check_raises src (Invalid_argument message) (fun () ->
          ignore (of_js (js_eval src))))
    [
      ("true", "Workero.Sql_value.of_js: unsupported JS value of type boolean");
      ("({})", "Workero.Sql_value.of_js: unsupported JS value of type object");
      ( "Symbol('s')",
        "Workero.Sql_value.of_js: unsupported JS value of type symbol" );
      ( "9223372036854775808n",
        "Workero.Sql_value.of_js: 9223372036854775808 is outside the int64 \
         range" );
      ( "-9223372036854775809n",
        "Workero.Sql_value.of_js: -9223372036854775809 is outside the int64 \
         range" );
    ];
  Alcotest.check value "Int16Array bytes" (Blob "\001\000\002\000")
    (of_js (js_eval "new Int16Array([1, 2])"));
  Alcotest.check value "DataView bytes" (Blob "\007")
    (of_js (js_eval "new DataView(new Uint8Array([7]).buffer)"))

let () =
  Alcotest.run "workero.sql_value"
    [
      ( "sql_value",
        [
          Alcotest.test_case "of_js" `Quick test_sql_value_of_js;
          Alcotest.test_case "to_js" `Quick test_sql_value_to_js;
          Alcotest.test_case "rejects" `Quick test_sql_value_rejects;
        ] );
    ]
