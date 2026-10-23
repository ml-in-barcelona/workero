open Workero

let outcome = function
  | Trace.Ok -> "ok"
  | Exception -> "exception"
  | Exceeded_cpu -> "exceeded_cpu"
  | Exceeded_memory -> "exceeded_memory"
  | Script_not_found -> "script_not_found"
  | Canceled -> "canceled"
  | Response_stream_disconnected -> "response_stream_disconnected"
  | Unknown s -> "unknown:" ^ s

let level = function
  | `Debug -> "debug"
  | `Info -> "info"
  | `Log -> "log"
  | `Warn -> "warn"
  | `Error -> "error"

let opt_string = function Some s -> `String s | None -> `Null
let opt_int = function Some n -> `Int n | None -> `Null

let event = function
  | Trace.Fetch { request; status } ->
      let unredacted = Trace.Request.unredacted request in
      `Assoc
        [
          ("kind", `String "fetch");
          ("url", `String (Trace.Request.url request));
          ("unredacted_url", `String (Trace.Request.url unredacted));
          ("method", `String (Trace.Request.method_ request));
          ( "headers",
            `Assoc
              (List.map
                 (fun (k, v) -> (k, `String v))
                 (Trace.Request.headers request)) );
          ( "unredacted_headers",
            `Assoc
              (List.map
                 (fun (k, v) -> (k, `String v))
                 (Trace.Request.headers unredacted)) );
          ("country", opt_string (Cf.country (Trace.Request.cf request)));
          ("status", opt_int status);
        ]
  | Scheduled { cron; scheduled_time } ->
      `Assoc
        [
          ("kind", `String "scheduled");
          ("cron", `String cron);
          ("scheduled_time", `Float scheduled_time);
        ]
  | Queue { queue; batch_size } ->
      `Assoc
        [
          ("kind", `String "queue");
          ("queue", `String queue);
          ("batch_size", `Int batch_size);
        ]
  | Alarm { scheduled_time } ->
      `Assoc
        [
          ("kind", `String "alarm");
          ("scheduled_time_set", `Bool (scheduled_time > 0.));
        ]
  | Email { mail_from; rcpt_to; raw_size } ->
      `Assoc
        [
          ("kind", `String "email");
          ("mail_from", `String mail_from);
          ("rcpt_to", `String rcpt_to);
          ("raw_size", `Int raw_size);
        ]
  | Rpc { method_ } ->
      `Assoc [ ("kind", `String "rpc"); ("method", `String method_) ]
  | Tail { consumed } ->
      `Assoc
        [
          ("kind", `String "tail");
          ("consumed", `List (List.map opt_string consumed));
        ]
  | Hibernatable_websocket ws ->
      `Assoc
        [
          ("kind", `String "hibernatable_websocket");
          ( "event",
            `String
              (match ws with
              | Ws_message -> "message"
              | Ws_close { code; was_clean } ->
                  Printf.sprintf "close:%d:%b" code was_clean
              | Ws_error -> "error") );
        ]
  | Custom -> `Assoc [ ("kind", `String "custom") ]
  | Other _ -> `Assoc [ ("kind", `String "other") ]

let item trace =
  `Assoc
    [
      ("outcome", `String (outcome (Trace.outcome trace)));
      ("event", event (Trace.event trace));
      ("event_timestamp_set", `Bool (Trace.event_timestamp trace > 0.));
      ("script_name", opt_string (Trace.script_name trace));
      ("truncated", `Bool (Trace.truncated trace));
      ( "logs",
        `List
          (List.map
             (fun (l : Trace.log) ->
               `Assoc
                 [
                   ("level", `String (level l.level));
                   ("timestamp_set", `Bool (l.timestamp > 0.));
                   ("message", `List l.message);
                 ])
             (Trace.logs trace)) );
      ( "exceptions",
        `List
          (List.map
             (fun (e : Trace.exn_info) ->
               `Assoc
                 [
                   ("name", `String e.name);
                   ("message", `String e.message);
                   ("has_stack", `Bool (Option.is_some e.stack));
                 ])
             (Trace.exceptions trace)) );
    ]

let stream_info = function
  | Trace.Stream.Fetch { method_; url; headers } ->
      `Assoc
        [
          ("kind", `String "fetch");
          ("method", `String method_);
          ("url", `String url);
          ("header_count", `Int (List.length headers));
        ]
  | Jsrpc -> `Assoc [ ("kind", `String "jsrpc") ]
  | Scheduled { cron; scheduled_time } ->
      `Assoc
        [
          ("kind", `String "scheduled");
          ("cron", `String cron);
          ("scheduled_time", `Float scheduled_time);
        ]
  | Alarm _ -> `Assoc [ ("kind", `String "alarm") ]
  | Queue { queue; batch_size } ->
      `Assoc
        [
          ("kind", `String "queue");
          ("queue", `String queue);
          ("batch_size", `Int batch_size);
        ]
  | Email _ -> `Assoc [ ("kind", `String "email") ]
  | Trace { traces } ->
      `Assoc
        [
          ("kind", `String "trace");
          ("traces", `List (List.map opt_string traces));
        ]
  | Hibernatable_websocket _ ->
      `Assoc [ ("kind", `String "hibernatable_websocket") ]
  | Custom -> `Assoc [ ("kind", `String "custom") ]
  | Other _ -> `Assoc [ ("kind", `String "other") ]

let stream_kind = function
  | Trace.Stream.Onset
      { info; span_id; script_name; execution_model; attributes; _ } ->
      `Assoc
        [
          ("kind", `String "onset");
          ("info", stream_info info);
          ("span_id_set", `Bool (span_id <> ""));
          ("script_name", opt_string script_name);
          ("execution_model", `String execution_model);
          ("attributes", `Int (List.length attributes));
        ]
  | Outcome { outcome = o; _ } ->
      `Assoc [ ("kind", `String "outcome"); ("outcome", `String (outcome o)) ]
  | Span_open { name; _ } ->
      `Assoc [ ("kind", `String "span_open"); ("name", `String name) ]
  | Span_close { outcome = o } ->
      `Assoc
        [ ("kind", `String "span_close"); ("outcome", `String (outcome o)) ]
  | Diagnostic_channel { channel; _ } ->
      `Assoc
        [ ("kind", `String "diagnostic_channel"); ("channel", `String channel) ]
  | Exception { name; message; stack } ->
      `Assoc
        [
          ("kind", `String "exception");
          ("name", `String name);
          ("message", `String message);
          ("has_stack", `Bool (Option.is_some stack));
        ]
  | Log { level = l; message } ->
      `Assoc
        [
          ("kind", `String "log");
          ("level", `String (level l));
          ("message", message);
        ]
  | Return { status } ->
      `Assoc [ ("kind", `String "return"); ("status", opt_int status) ]
  | Attributes attributes ->
      `Assoc
        [
          ("kind", `String "attributes");
          ("count", `Int (List.length attributes));
        ]
  | Other _ -> `Assoc [ ("kind", `String "other") ]

let stream_event e =
  `Assoc
    [
      ("invocation_id", `String (Trace.Stream.invocation_id e));
      ("trace_id_set", `Bool (Trace.Stream.trace_id e <> ""));
      ("timestamp_set", `Bool (Trace.Stream.timestamp e > 0.));
      ("sequence", `Int (Trace.Stream.sequence e));
      ("event", stream_kind (Trace.Stream.kind e));
    ]

let post sink kind body =
  ignore
    (Fetcher.fetch ~method_:POST ~body:(Jsonkit.to_string body) sink
       ("http://sink/" ^ kind))

let () =
  Workero.tail (fun traces env ctx ->
      let sink = Fetcher.of_env env "SINK" in
      List.iter (fun trace -> post sink "items" (item trace)) traces;
      Context.wait_until ctx (fun () ->
          post sink "after" (`Int (List.length traces))))

let () =
  Workero.tail_stream (fun onset env _ctx ->
      let sink = Fetcher.of_env env "SINK" in
      post sink "stream" (stream_event onset);
      fun event -> post sink "stream" (stream_event event))
