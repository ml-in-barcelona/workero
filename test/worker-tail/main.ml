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

let post sink kind body =
  ignore
    (Fetcher.fetch ~method_:POST ~body:(Jsonkit.to_string body) sink
       ("http://sink/" ^ kind))

let () =
  Workero.tail (fun traces env ctx ->
      let sink = Fetcher.of_env env "SINK" in
      List.iter (fun trace -> post sink "item" (item trace)) traces;
      Context.wait_until ctx (fun () ->
          post sink "after" (`Int (List.length traces))))
