open Helpers
module Queue = Workero.Queue

let producer = js_eval "({ send() {}, sendBatch() {} })"
let env_of fields = Workero.Env.of_js (obj (Array.of_list fields))

let test_of_env () =
  let env = env_of [ ("JOBS", producer); ("TEXT", jstr "plain") ] in
  ignore (Queue.of_env env "JOBS");
  Alcotest.check_raises "missing"
    (Invalid_argument "Workero.Queue.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Queue.of_env env "NOPE"));
  Alcotest.check_raises "a variable"
    (Invalid_argument
       "Workero.Queue.of_env: binding \"TEXT\" is a string, not a queue \
        producer") (fun () -> ignore (Queue.of_env env "TEXT"));
  let half = env_of [ ("HALF", js_eval "({ send() {} })") ] in
  Alcotest.check_raises "no sendBatch"
    (Invalid_argument
       "Workero.Queue.of_env: binding \"HALF\" is an object without method \
        sendBatch, not a queue producer") (fun () ->
      ignore (Queue.of_env half "HALF"))

let invalid_delay who n f =
  Alcotest.check_raises
    (Printf.sprintf "%s %d" who n)
    (Invalid_argument
       (Printf.sprintf "%s: delay_seconds %d is outside 0 to 86400" who n))
    f

let test_delay_validation () =
  let q = Queue.of_env (env_of [ ("JOBS", producer) ]) "JOBS" in
  List.iter
    (fun n ->
      invalid_delay "Workero.Queue.message" n (fun () ->
          ignore (Queue.message ~delay_seconds:n (Queue.Text "x")));
      invalid_delay "Workero.Queue.send" n (fun () ->
          Queue.send ~delay_seconds:n q (Queue.Text "x"));
      invalid_delay "Workero.Queue.send_batch" n (fun () ->
          Queue.send_batch ~delay_seconds:n q []))
    [ -1; 86401 ];
  ignore (Queue.message ~delay_seconds:0 (Queue.Text "x"));
  ignore (Queue.message ~delay_seconds:86400 (Queue.Text "x"))

let test_message_json_nan () =
  match Queue.message (Queue.Json (`Float Float.nan)) with
  | _ -> Alcotest.fail "no exception"
  | exception Invalid_argument _ -> ()

let message_js =
  js_eval
    {|(function (body) {
        const calls = [];
        return {
          id: "m1", timestamp: new Date(1700000000000), attempts: 2, body, calls,
          ack() { calls.push(["ack"]); },
          retry(...args) { calls.push(["retry", ...args]); },
        };
      })|}

let message body =
  Workero.Queue.Message.of_js
    (Js_of_ocaml.Js.Unsafe.fun_call message_js [| body |])

let calls m =
  Js_of_ocaml.Js.to_string
    (Js_of_ocaml.Js.Unsafe.fun_call
       (js_eval "(m => JSON.stringify(m.calls))")
       [| Queue.Message.to_js m |])

let test_message_fields () =
  let m = message (js_eval "({ a: [1, 2] })") in
  Alcotest.(check string) "id" "m1" (Queue.Message.id m);
  Alcotest.(check (float 0.))
    "timestamp" 1700000000000.
    (Queue.Message.timestamp m);
  Alcotest.(check int) "attempts" 2 (Queue.Message.attempts m);
  Alcotest.(check string)
    "json" {|{"a":[1,2]}|}
    (Jsonkit.to_string (Queue.Message.body_json m))

let test_message_bodies () =
  let text = message (jstr "h\xc3\xa9llo") in
  Alcotest.(check string) "text" "h\xc3\xa9llo" (Queue.Message.body_text text);
  Alcotest.(check string)
    "a text body reads as a JSON string" "\"h\xc3\xa9llo\""
    (Jsonkit.to_string (Queue.Message.body_json text));
  let bytes = message (js_eval "new Uint8Array([0, 255, 1]).buffer") in
  Alcotest.(check string)
    "bytes" "\x00\xff\x01"
    (Queue.Message.body_bytes bytes);
  let wrong = message (js_eval "({ a: 1 })") in
  Alcotest.check_raises "text of an object"
    (Invalid_argument "Workero.Decode: expected string, got object") (fun () ->
      ignore (Queue.Message.body_text wrong));
  Alcotest.check_raises "bytes of a string"
    (Invalid_argument "Workero.Decode: expected bytes, got string") (fun () ->
      ignore (Queue.Message.body_bytes text));
  Alcotest.(check string)
    "body_js" "object"
    (Js_of_ocaml.Js.to_string
       (Js_of_ocaml.Js.typeof
          (Js_of_ocaml.Js.Unsafe.coerce (Queue.Message.body_js wrong))))

let test_ack_retry () =
  let m = message (jstr "x") in
  Queue.Message.ack m;
  Queue.Message.retry m;
  Queue.Message.retry ~delay_seconds:5 m;
  Alcotest.(check string)
    "calls" {|[["ack"],["retry"],["retry",{"delaySeconds":5}]]|} (calls m);
  invalid_delay "Workero.Queue.Message.retry" 86401 (fun () ->
      Queue.Message.retry ~delay_seconds:86401 m);
  Alcotest.(check string)
    "an invalid delay calls nothing"
    {|[["ack"],["retry"],["retry",{"delaySeconds":5}]]|} (calls m)

let test_ack_throws () =
  let m =
    Queue.Message.of_js (js_eval "({ ack() { throw new Error('closed'); } })")
  in
  raises_js_error "ack" (fun () -> Queue.Message.ack m)

let batch_js =
  js_eval
    {|(function () {
        const calls = [];
        const message = (id) => ({ id });
        return {
          queue: "jobs", messages: [message("a"), message("b"), message("c")], calls,
          ackAll() { calls.push(["ackAll"]); },
          retryAll(...args) { calls.push(["retryAll", ...args]); },
        };
      })|}

let test_batch () =
  let b = Queue.Batch.of_js (Js_of_ocaml.Js.Unsafe.fun_call batch_js [||]) in
  Alcotest.(check string) "queue" "jobs" (Queue.Batch.queue b);
  Alcotest.(check (list string))
    "messages in order" [ "a"; "b"; "c" ]
    (List.map Queue.Message.id (Queue.Batch.messages b));
  Queue.Batch.ack_all b;
  Queue.Batch.retry_all b;
  Queue.Batch.retry_all ~delay_seconds:7 b;
  Alcotest.(check string)
    "calls" {|[["ackAll"],["retryAll"],["retryAll",{"delaySeconds":7}]]|}
    (Js_of_ocaml.Js.to_string
       (Js_of_ocaml.Js.Unsafe.fun_call
          (js_eval "(b => JSON.stringify(b.calls))")
          [| Queue.Batch.to_js b |]));
  invalid_delay "Workero.Queue.Batch.retry_all" (-1) (fun () ->
      Queue.Batch.retry_all ~delay_seconds:(-1) b)

let () =
  Alcotest.run "workero.queue"
    [
      ( "queue",
        [
          Alcotest.test_case "of_env" `Quick test_of_env;
          Alcotest.test_case "delay validation" `Quick test_delay_validation;
          Alcotest.test_case "json nan" `Quick test_message_json_nan;
          Alcotest.test_case "message fields" `Quick test_message_fields;
          Alcotest.test_case "message bodies" `Quick test_message_bodies;
          Alcotest.test_case "ack and retry" `Quick test_ack_retry;
          Alcotest.test_case "ack throws" `Quick test_ack_throws;
          Alcotest.test_case "batch" `Quick test_batch;
        ] );
    ]
