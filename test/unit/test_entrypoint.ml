module Entrypoint = Workero.Entrypoint
module Durable_object = Workero.Durable_object

let who = "Workero.Entrypoint.register"
let create _ _ = Entrypoint.make ()

let invalid name message f =
  Alcotest.check_raises name (Invalid_argument (who ^ ": " ^ message)) f

let test_class_names () =
  Entrypoint.register "Math" ~rpc:[] create;
  Entrypoint.register "$Calc_2" ~rpc:[ "add"; "plus_1"; "$x" ] create;
  List.iter
    (fun name ->
      invalid name (Printf.sprintf "%S is not a valid class name" name)
        (fun () -> Entrypoint.register name ~rpc:[] create))
    [ ""; "2fast"; "has space"; "dash-ed"; "default"; "then"; "__proto__" ]

let test_method_names () =
  List.iter
    (fun m ->
      invalid m (Printf.sprintf "%S is not a valid method name" m) (fun () ->
          Entrypoint.register "Methods" ~rpc:[ "ok"; m ] create))
    [
      ""; "2x"; "a b"; "a-b"; "constructor"; "fetch"; "then"; "env"; "__proto__";
    ];
  invalid "duplicate method" "class \"Methods\" repeats a method name"
    (fun () -> Entrypoint.register "Methods" ~rpc:[ "a"; "a" ] create)

let test_register_twice () =
  Entrypoint.register "Twice" ~rpc:[] create;
  invalid "duplicate class" "class \"Twice\" is already registered" (fun () ->
      Entrypoint.register "Twice" ~rpc:[] create)

let test_clash_with_durable_object () =
  Durable_object.register "Shared" (fun _ _ -> Durable_object.make ());
  invalid "same name as a Durable Object class"
    "class \"Shared\" is already registered" (fun () ->
      Entrypoint.register "Shared" ~rpc:[] create)

let () =
  Alcotest.run "workero.entrypoint"
    [
      ( "entrypoint",
        [
          Alcotest.test_case "register validates class names" `Quick
            test_class_names;
          Alcotest.test_case "register validates method names" `Quick
            test_method_names;
          Alcotest.test_case "register twice" `Quick test_register_twice;
          Alcotest.test_case "name of a Durable Object class" `Quick
            test_clash_with_durable_object;
        ] );
    ]
