open Helpers
module Workflow = Workero.Workflow
module Entrypoint = Workero.Entrypoint
module Durable_object = Workero.Durable_object

let who = "Workero.Workflow.register"
let run _ _ _ = `Null

let invalid name message f =
  Alcotest.check_raises name (Invalid_argument message) f

let test_register_names () =
  Workflow.register "Greet" run;
  Workflow.register "$Flow_2" run;
  List.iter
    (fun name ->
      invalid name (Printf.sprintf "%s: %S is not a valid class name" who name)
        (fun () -> Workflow.register name run))
    [ ""; "2fast"; "has space"; "dash-ed"; "default"; "then"; "__proto__" ]

let test_register_twice () =
  Workflow.register "Twice" run;
  invalid "duplicate" (who ^ ": class \"Twice\" is already registered")
    (fun () -> Workflow.register "Twice" run)

let test_clash_with_other_kinds () =
  Durable_object.register "WfDo" (fun _ _ -> Durable_object.make ());
  Entrypoint.register "WfEntry" (fun _ _ -> Entrypoint.make ());
  invalid "Durable Object" (who ^ ": class \"WfDo\" is already registered")
    (fun () -> Workflow.register "WfDo" run);
  invalid "entrypoint" (who ^ ": class \"WfEntry\" is already registered")
    (fun () -> Workflow.register "WfEntry" run);
  Workflow.register "WfFlow" run;
  invalid "workflow, from an entrypoint"
    "Workero.Entrypoint.register: class \"WfFlow\" is already registered"
    (fun () -> Entrypoint.register "WfFlow" (fun _ _ -> Entrypoint.make ()))

let test_duration () =
  List.iter
    (fun (name, f) ->
      invalid name
        (Printf.sprintf "Workero.Workflow.Duration.%s: negative duration" name)
        (fun () -> ignore (f (-1))))
    [
      ("ms", Workflow.Duration.ms);
      ("seconds", Workflow.Duration.seconds);
      ("minutes", Workflow.Duration.minutes);
      ("hours", Workflow.Duration.hours);
      ("days", Workflow.Duration.days);
    ];
  ignore (Workflow.Duration.days 0)

let test_retries () =
  let delay = Workflow.Duration.ms 1 in
  List.iter
    (fun limit ->
      invalid (string_of_int limit)
        "Workero.Workflow.Step.retries: limit must be in 0..10000" (fun () ->
          ignore (Workflow.Step.retries ~limit ~delay ())))
    [ -1; 10_001 ];
  ignore (Workflow.Step.retries ~limit:0 ~delay ());
  ignore (Workflow.Step.retries ~limit:10_000 ~backoff:Constant ~delay ())

let test_options () =
  invalid "id too long"
    "Workero.Workflow.options: the instance id is longer than 100 characters"
    (fun () -> ignore (Workflow.options ~id:(String.make 101 'x') ()));
  ignore (Workflow.options ~id:(String.make 100 'x') ~params:`Null ())

let test_of_env () =
  let env =
    Workero.Env.of_js
      (obj
         [|
           ("FLOW", js_eval "({ create() {}, createBatch() {}, get() {} })");
           ("NO_GET", js_eval "({ create() {}, createBatch() {} })");
           ("TEXT", jstr "x");
         |])
  in
  ignore (Workflow.of_env env "FLOW");
  invalid "missing" "Workero.Workflow.of_env: binding \"NOPE\" not found"
    (fun () -> ignore (Workflow.of_env env "NOPE"));
  invalid "no get"
    "Workero.Workflow.of_env: binding \"NO_GET\" is an object without method \
     get, not a Workflow binding" (fun () ->
      ignore (Workflow.of_env env "NO_GET"));
  invalid "not an object"
    "Workero.Workflow.of_env: binding \"TEXT\" is a string, not a Workflow \
     binding" (fun () -> ignore (Workflow.of_env env "TEXT"))

let () =
  Alcotest.run "workero.workflow"
    [
      ( "workflow",
        [
          Alcotest.test_case "register validates class names" `Quick
            test_register_names;
          Alcotest.test_case "register twice" `Quick test_register_twice;
          Alcotest.test_case "name of another kind of class" `Quick
            test_clash_with_other_kinds;
          Alcotest.test_case "Duration rejects negative counts" `Quick
            test_duration;
          Alcotest.test_case "Step.retries checks the limit" `Quick test_retries;
          Alcotest.test_case "options checks the id length" `Quick test_options;
          Alcotest.test_case "of_env" `Quick test_of_env;
        ] );
    ]
