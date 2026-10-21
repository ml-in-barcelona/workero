open Helpers

let env fields = Workero.Env.of_js (obj (Array.of_list fields))

let json_text =
  Alcotest.testable
    (fun ppf j -> Format.pp_print_string ppf (Jsonkit.to_string j))
    (fun a b -> Jsonkit.to_string a = Jsonkit.to_string b)

let test_env_var () =
  let env = env [ ("A", jstr "x"); ("B", inject 1) ] in
  Alcotest.(check (option string)) "string" (Some "x") (Workero.Env.var env "A");
  Alcotest.(check (option string)) "not a string" None (Workero.Env.var env "B");
  Alcotest.(check (option string)) "missing" None (Workero.Env.var env "C")

let test_secret () =
  let env =
    env
      [
        ("A", jstr "s3cret");
        ("B", inject 42);
        ("C", obj [||]);
        ("N", js_eval "null");
      ]
  in
  Alcotest.check_raises "null"
    (Invalid_argument "Workero.Env.secret: \"N\" is null, not a string")
    (fun () -> ignore (Workero.Env.secret env "N"));
  Alcotest.(check string) "string" "s3cret" (Workero.Env.secret env "A");
  Alcotest.check_raises "missing"
    (Invalid_argument "Workero.Env.secret: \"Z\" not found") (fun () ->
      ignore (Workero.Env.secret env "Z"));
  Alcotest.check_raises "number"
    (Invalid_argument "Workero.Env.secret: \"B\" is a number, not a string")
    (fun () -> ignore (Workero.Env.secret env "B"));
  Alcotest.check_raises "object"
    (Invalid_argument "Workero.Env.secret: \"C\" is an object, not a string")
    (fun () -> ignore (Workero.Env.secret env "C"));
  Alcotest.check_raises "inherited"
    (Invalid_argument "Workero.Env.secret: \"toString\" not found") (fun () ->
      ignore (Workero.Env.secret env "toString"))

let test_json () =
  let env =
    env
      [
        ("OBJ", js_eval "({ foo: 42, nested: { ok: true } })");
        ("ARR", js_eval "[1, 'two']");
        ("STR", jstr "text");
        ("NUM", inject 1);
        ("NULL", js_eval "null");
      ]
  in
  Alcotest.(check (option json_text))
    "object"
    (Some
       (`Assoc [ ("foo", `Int 42); ("nested", `Assoc [ ("ok", `Bool true) ]) ]))
    (Workero.Env.json env "OBJ");
  Alcotest.(check (option json_text))
    "array"
    (Some (`List [ `Int 1; `String "two" ]))
    (Workero.Env.json env "ARR");
  List.iter
    (fun name ->
      Alcotest.(check (option json_text)) name None (Workero.Env.json env name))
    [ "STR"; "NUM"; "NULL"; "MISSING"; "__proto__"; "toString" ];
  Alcotest.(check (option string))
    "var ignores an object" None
    (Workero.Env.var env "OBJ")

let test_json_without_json_form () =
  let env =
    env [ ("CYCLE", js_eval "(() => { const o = {}; o.o = o; return o })()") ]
  in
  match Workero.Env.json env "CYCLE" with
  | _ -> Alcotest.fail "no exception"
  | exception Invalid_argument _ -> ()

let () =
  Alcotest.run "workero.env"
    [
      ( "env",
        [
          Alcotest.test_case "var" `Quick test_env_var;
          Alcotest.test_case "secret" `Quick test_secret;
          Alcotest.test_case "json" `Quick test_json;
          Alcotest.test_case "json without a json form" `Quick
            test_json_without_json_form;
        ] );
    ]
