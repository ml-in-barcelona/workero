open Workero

let hex s =
  String.concat ""
    (List.init (String.length s) (fun i ->
         Printf.sprintf "%02x" (Char.code s.[i])))

let json_body =
  `Assoc [ ("id", `Int 7); ("tags", `List [ `String "a"; `String "b" ]) ]

let delay url = Option.map int_of_string (URL.query url "delay")

let content_type url =
  match URL.query url "ct" with
  | Some "v8" -> Some `V8
  | Some "json" -> Some `Json
  | Some "text" -> Some `Text
  | Some "bytes" -> Some `Bytes
  | _ -> None

let invalid f =
  match f () with
  | () -> "ok"
  | exception Invalid_argument message -> "invalid: " ^ message

let handle req env _ctx =
  let url = Request.url req in
  let jobs () = Queue.of_env env "JOBS" in
  let delay_seconds = delay url in
  match URL.path url with
  | "/queue/send" ->
      let body =
        match URL.query url "kind" with
        | Some "json" -> Queue.Json json_body
        | Some "bytes" -> Queue.Bytes "\x00\xff\x80\n"
        | _ -> Queue.Text "h\xc3\xa9llo"
      in
      Queue.send ?content_type:(content_type url) ?delay_seconds (jobs ()) body;
      Some (Response.text "sent")
  | "/queue/send-batch" ->
      Queue.send_batch ?delay_seconds (jobs ())
        [
          Queue.message ~delay_seconds:9 (Queue.Json json_body);
          Queue.message (Queue.Text "plain");
          Queue.message (Queue.Bytes "\x00\xff");
        ];
      Some (Response.text "sent")
  | "/queue/send-batch-v8" ->
      Queue.send_batch (jobs ())
        [
          Queue.message ~content_type:`V8 (Queue.Json json_body);
          Queue.message ~content_type:`V8 ~delay_seconds:3 (Queue.Text "plain");
          Queue.message (Queue.Text "default");
        ];
      Some (Response.text "sent")
  | "/queue/send-batch-empty" ->
      Queue.send_batch (jobs ()) [];
      Some (Response.text "sent")
  | "/queue/send-rejected" -> (
      match Queue.send (jobs ()) (Queue.Text "reject") with
      | () -> Some (Response.text "unreachable")
      | exception Js_error e ->
          Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e)))
  | "/queue/bad-content-type" ->
      Some
        (Response.text
           (String.concat "\n"
              [
                invalid (fun () ->
                    Queue.send ~content_type:`Text (jobs ())
                      (Queue.Json json_body));
                invalid (fun () ->
                    ignore (Queue.message ~content_type:`Bytes (Queue.Text "x")));
              ]))
  | "/queue/bad-delay" ->
      let n = Option.value delay_seconds ~default:0 in
      let results =
        [
          invalid (fun () ->
              Queue.send ~delay_seconds:n (jobs ()) (Queue.Text "x"));
          invalid (fun () ->
              ignore (Queue.message ~delay_seconds:n (Queue.Text "x")));
          invalid (fun () ->
              Queue.send_batch ~delay_seconds:n (jobs ())
                [ Queue.message (Queue.Text "x") ]);
        ]
      in
      Some (Response.text (String.concat "\n" results))
  | "/queue/shape" ->
      let name = Option.value (URL.query url "name") ~default:"" in
      Some
        (Response.text
           (match Queue.of_env env name with
           | _ -> "ok"
           | exception Invalid_argument message -> message))
  | _ -> None

let summary message =
  Printf.sprintf "id=%s;ts=%.0f;attempts=%d" (Queue.Message.id message)
    (Queue.Message.timestamp message)
    (Queue.Message.attempts message)

let ack_by_body message =
  match Queue.Message.body_text message with
  | "ack" -> Queue.Message.ack message
  | "retry" -> Queue.Message.retry message
  | "retry5" -> Queue.Message.retry ~delay_seconds:5 message
  | _ -> ()

let consume batch env _ctx =
  let jobs = Queue.of_env env "JOBS" in
  let report text = Queue.send jobs (Queue.Text text) in
  let messages = Queue.Batch.messages batch in
  match Queue.Batch.queue batch with
  | "read-json" ->
      List.iter
        (fun m ->
          report
            (Printf.sprintf "%s;json=%s" (summary m)
               (Jsonkit.to_string (Queue.Message.body_json m))))
        messages
  | "read-text" ->
      List.iter
        (fun m ->
          report
            (Printf.sprintf "%s;text=%s" (summary m)
               (Queue.Message.body_text m)))
        messages
  | "read-bytes" ->
      List.iter
        (fun m ->
          report
            (Printf.sprintf "%s;bytes=%s" (summary m)
               (hex (Queue.Message.body_bytes m))))
        messages
  | "read-wrong-type" ->
      List.iter
        (fun m ->
          report
            (match Queue.Message.body_text m with
            | _ -> "no error"
            | exception Invalid_argument message -> "invalid: " ^ message))
        messages
  | "by-body" -> List.iter ack_by_body messages
  | "ack-all" -> Queue.Batch.ack_all batch
  | "retry-all" -> Queue.Batch.retry_all batch
  | "retry-all-delay" -> Queue.Batch.retry_all ~delay_seconds:7 batch
  | "bad-delay" ->
      report
        (invalid (fun () -> Queue.Batch.retry_all ~delay_seconds:86401 batch));
      List.iter
        (fun m ->
          report (invalid (fun () -> Queue.Message.retry ~delay_seconds:(-1) m)))
        messages
  | "raise-after-ack" -> (
      match messages with
      | first :: _ ->
          Queue.Message.ack first;
          failwith "consumer failed"
      | [] -> ())
  | "count" -> report (string_of_int (List.length messages))
  | other -> failwith ("no such test queue: " ^ other)
