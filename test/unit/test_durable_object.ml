open Helpers
module Durable_object = Workero.Durable_object

let create _ _ = Durable_object.make ()
let who = "Workero.Durable_object.register"

let test_register_names () =
  Durable_object.register "Counter" create;
  Durable_object.register "$Room_2" create;
  List.iter
    (fun name ->
      Alcotest.check_raises name
        (Invalid_argument
           (Printf.sprintf "%s: %S is not a valid class name" who name))
        (fun () -> Durable_object.register name create))
    [ ""; "2fast"; "has space"; "dash-ed"; "quote\"" ]

let test_register_twice () =
  Durable_object.register "Twice" create;
  Alcotest.check_raises "duplicate"
    (Invalid_argument (who ^ ": class \"Twice\" is already registered"))
    (fun () -> Durable_object.register "Twice" create)

let test_namespace_of_env () =
  let env =
    Workero.Env.of_js
      (obj
         [|
           ( "DO",
             js_eval
               "({ idFromName() {}, idFromString() {}, newUniqueId() {}, get() \
                {} })" );
           ("KV", js_eval "({ get() {} })");
         |])
  in
  ignore (Durable_object.Namespace.of_env env "DO");
  Alcotest.check_raises "missing"
    (Invalid_argument
       "Workero.Durable_object.Namespace.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Durable_object.Namespace.of_env env "NOPE"));
  Alcotest.check_raises "not a namespace"
    (Invalid_argument
       "Workero.Durable_object.Namespace.of_env: binding \"KV\" is an object \
        without method idFromName, not a Durable Object namespace") (fun () ->
      ignore (Durable_object.Namespace.of_env env "KV"))

let () =
  Alcotest.run "workero.durable_object"
    [
      ( "durable_object",
        [
          Alcotest.test_case "register validates names" `Quick
            test_register_names;
          Alcotest.test_case "register twice" `Quick test_register_twice;
          Alcotest.test_case "Namespace.of_env" `Quick test_namespace_of_env;
        ] );
    ]
