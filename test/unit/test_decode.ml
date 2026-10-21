open Helpers

let test_decode () =
  let open Workero.Decode in
  let v = js_eval "({ a: [1, 2, null], b: 'x', c: true, d: 1.5, e: null })" in
  Alcotest.(check (list (option int)))
    "list of option" [ Some 1; Some 2; None ]
    (field "a" (list (option int)) v);
  Alcotest.(check string) "string" "x" (field "b" string v);
  Alcotest.(check bool) "bool" true (field "c" bool v);
  Alcotest.(check (float 0.)) "float" 1.5 (field "d" float v);
  Alcotest.(check (option string)) "null" None (field "e" (option string) v);
  Alcotest.(check (option string)) "absent" None (field "z" (option string) v);
  Alcotest.(check string)
    "bytes" "\000\255"
    (bytes (js_eval "new Uint8Array([0, 255])"));
  let check_raises decode src message =
    Alcotest.check_raises src (Invalid_argument message) (fun () ->
        Stdlib.ignore (decode (js_eval src)))
  in
  check_raises
    (fun v -> Stdlib.ignore (string v))
    "5" "Workero.Decode: expected string, got number";
  check_raises
    (fun v -> Stdlib.ignore (int v))
    "'x'" "Workero.Decode: expected number, got string";
  check_raises
    (fun v -> Stdlib.ignore (int v))
    "1.5" "Workero.Decode: expected an integer, got a fraction";
  check_raises
    (fun v -> Stdlib.ignore (bool v))
    "null" "Workero.Decode: expected boolean, got null or undefined";
  check_raises
    (fun v -> Stdlib.ignore (list string v))
    "({})" "Workero.Decode: expected array, got object";
  check_raises
    (fun v -> Stdlib.ignore (bytes v))
    "'x'" "Workero.Decode: expected bytes, got string"

let () =
  Alcotest.run "workero.decode"
    [ ("decode", [ Alcotest.test_case "decoders" `Quick test_decode ]) ]
