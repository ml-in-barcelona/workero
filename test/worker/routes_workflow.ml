open Workero
module W = Workflow
module S = W.Step

let int_of = function `Int n -> n | _ -> invalid_arg "expected an int"

let scenario params =
  match params with
  | `Assoc fields -> (
      match List.assoc_opt "scenario" fields with
      | Some (`String s) -> s
      | _ -> "basic")
  | _ -> "basic"

let caught_invalid name f =
  match f () with
  | _ -> `String (name ^ ": no exception")
  | exception Invalid_argument m -> `String m

let run env (event : W.event) step =
  match scenario event.payload with
  | "basic" ->
      let n =
        int_of
          (S.do_ step "first" (fun _ ->
               Promise.await (Timer.sleep 2);
               `Int 21))
      in
      let doubled = S.do_ step "double" (fun _ -> `Int (n * 2)) in
      `Assoc
        [
          ("doubled", doubled);
          ("payload", event.payload);
          ("instance_id", `String event.instance_id);
          ("timestamp_is_recent", `Bool (event.timestamp > 1e12));
          ( "greeting",
            `String (Option.value (Env.var env "GREETING") ~default:"none") );
        ]
  | "sleep" ->
      let before = S.do_ step "before" (fun _ -> `String "b") in
      S.sleep step "nap" (W.Duration.ms 20);
      let at =
        S.do_ step "when" (fun _ ->
            `String (Printf.sprintf "%.0f" (Date.now () +. 30.)))
      in
      (match at with
      | `String at -> S.sleep_until step "until" (float_of_string at)
      | _ -> ());
      let after = S.do_ step "after" (fun _ -> `String "a") in
      `List [ before; after ]
  | "retry" ->
      let seen = ref [] in
      S.do_ step "flaky"
        ~retries:
          (S.retries ~backoff:S.Linear ~limit:3 ~delay:(W.Duration.ms 1) ())
        ~timeout:(W.Duration.seconds 5)
        (fun { attempt; _ } ->
          seen := attempt :: !seen;
          if attempt < 3 then failwith "flaky";
          `List (List.rev_map (fun n -> `Int n) !seen))
  | "exhausted" -> (
      match
        S.do_ step "always"
          ~retries:(S.retries ~limit:1 ~delay:(W.Duration.ms 1) ())
          (fun _ -> failwith "boom")
      with
      | _ -> `String "unreachable"
      | exception Js_error _ -> `String "gave up")
  | "stop" ->
      S.do_ step "stop" (fun _ -> raise (W.Non_retryable "do not retry"))
  | "stop_caught" -> (
      match S.do_ step "stop" (fun _ -> raise (W.Non_retryable "no")) with
      | _ -> `String "unreachable"
      | exception Js_error e ->
          let after = S.do_ step "after" (fun _ -> `String "recovered") in
          `List [ after; `Bool (String.length (Promise.error_to_string e) > 0) ]
      )
  | "event" ->
      let e = S.wait_for_event step "approval" ~type_:"approve" in
      `Assoc [ ("approved", e.event_payload) ]
  | "event_timeout" -> (
      match
        S.wait_for_event step "approval" ~type_:"approve"
          ~timeout:(W.Duration.ms 30)
      with
      | _ -> `String "unreachable"
      | exception Js_error _ ->
          S.do_ step "after" (fun _ -> `String "timed out"))
  | "invalid" ->
      `List
        [
          caught_invalid "type" (fun () ->
              S.wait_for_event step "w" ~type_:"bad.type");
          caught_invalid "name" (fun () ->
              S.sleep step (String.make 257 'x') (W.Duration.ms 1);
              `Null);
        ]
  | "slow" ->
      S.do_ step "slow" (fun _ ->
          Promise.await (Timer.sleep 200);
          `String "slow done")
  | "rich" ->
      let step_result =
        S.do_ step "rich" (fun _ ->
            `Assoc
              [
                ("date", `Date 172_800_000.);
                ("bytes", `Bytes "\000\255");
                ("map", `Map [ (`String "k", `Set [ `Int 1 ]) ]);
                ("undefined", `Undefined);
              ])
      in
      let sent = (S.wait_for_event step "go" ~type_:"go").event_payload in
      `Assoc
        [ ("step", step_result); ("payload", event.payload); ("event", sent) ]
  | "undefined" ->
      let step_result = S.do_ step "undefined" (fun _ -> `Undefined) in
      let sent = (S.wait_for_event step "go" ~type_:"go").event_payload in
      `Assoc [ ("step", step_result); ("event", sent) ]
  | "ctx" ->
      let describe (c : S.context) =
        `Assoc
          [
            ("name", `String c.step_name);
            ("count", `Int c.step_count);
            ("attempt", `Int c.attempt);
            ( "limit",
              match c.config.retries_limit with
              | Some n -> `Int n
              | None -> `Null );
            ( "backoff",
              match c.config.backoff with
              | Some S.Linear -> `String "linear"
              | Some S.Constant -> `String "constant"
              | Some S.Exponential -> `String "exponential"
              | None -> `Null );
          ]
      in
      let retries =
        S.retries ~backoff:S.Linear ~limit:4 ~delay:(W.Duration.ms 1) ()
      in
      let first = S.do_ step "ctx" ~retries describe in
      let second = S.do_ step "ctx" (fun c -> describe c) in
      let default = S.do_ step "plain" describe in
      `List [ first; second; default ]
  | "delay_fn" ->
      S.do_ step "flaky"
        ~retries:
          (S.retries_with ~limit:3 (fun d ->
               W.Duration.ms
                 ((1000 * if snd d.delay_error <> "" then 1 else 0)
                 + (10 * d.delay_ctx.step_count)
                 + d.delay_ctx.attempt)))
        (fun c ->
          if c.attempt < 3 then failwith "flaky";
          `Int c.attempt)
  | "rollback" ->
      let undo (r : S.rollback_context) =
        failwith
          (Printf.sprintf "undo %s %s %s" r.rollback_ctx.step_name
             (match r.rollback_output with `String s -> s | _ -> "?")
             (snd r.rollback_error))
      in
      let _ =
        S.do_ step "a" ~rollback:(S.rollback undo) (fun _ -> `String "A")
      in
      let _ =
        S.do_ step "b"
          ~rollback:(S.rollback ~timeout:(W.Duration.seconds 5) undo)
          (fun _ -> `String "B")
      in
      S.do_ step "boom" (fun _ -> raise (W.Non_retryable "stop here"))
  | "rollback_wait" ->
      let _ =
        S.do_ step "a"
          ~rollback:
            (S.rollback (fun r -> failwith ("undo " ^ r.rollback_ctx.step_name)))
          (fun _ -> `String "A")
      in
      (S.wait_for_event step "never" ~type_:"never").event_payload
  | "steps" ->
      let one = S.do_ step "one" (fun _ -> `Int 1) in
      let two = S.do_ step "two" (fun _ -> `Int 2) in
      S.sleep step "nap" (W.Duration.ms 5);
      let three = S.do_ step "two" (fun _ -> `Int 3) in
      `List [ one; two; three ]
  | "event_full" ->
      let e = S.wait_for_event step "approval" ~type_:"approve" in
      `Assoc
        [
          ("type", `String e.event_type);
          ("payload", e.event_payload);
          ("recent", `Bool (e.event_timestamp > 1e12));
        ]
  | "fail" -> failwith "run failed"
  | other -> invalid_arg ("unknown scenario " ^ other)

let () = W.register "Flow" run

let () =
  W.register "FullFlow" (fun _env (e : W.event) _step ->
      `Assoc
        [
          ("workflow_name", `String e.workflow_name);
          ("instance_id", `String e.instance_id);
          ("payload", e.payload);
          ( "schedule",
            match e.schedule with
            | None -> `Null
            | Some s ->
                `Assoc
                  [
                    ("cron", `String s.cron);
                    ("scheduled_time", `Float s.scheduled_time);
                  ] );
        ])

let rich : Rpc.value =
  `Assoc
    [
      ("scenario", `String "rich");
      ("when", `Date 86_400_000.);
      ("data", `Bytes "\000\001\255");
      ("big", `Bigint "12345678901234567890");
    ]

let json_or_null = function
  | None -> None
  | Some s -> Some (Rpc.to_value (Rpc.of_json (Jsonkit.of_string s)))

let value_arg url name =
  match (URL.query url "rich", URL.query url "undefined") with
  | Some _, _ -> Some rich
  | None, Some _ -> Some `Undefined
  | None, None -> json_or_null (URL.query url name)

let params_of url = value_arg url "params"

let rec tagged : Rpc.value -> Jsonkit.t = function
  | `Undefined -> `Assoc [ ("$undefined", `Bool true) ]
  | `Null -> `Null
  | `Bool b -> `Bool b
  | `Int n -> `Int n
  | `Float f -> `Float f
  | `String s -> `String s
  | `List l -> `List (List.map tagged l)
  | `Assoc l -> `Assoc (List.map (fun (k, v) -> (k, tagged v)) l)
  | `Bytes s ->
      `Assoc
        [
          ( "$bytes",
            `List
              (List.init (String.length s) (fun i -> `Int (Char.code s.[i]))) );
        ]
  | `Date f -> `Assoc [ ("$date", `Float f) ]
  | `Bigint s -> `Assoc [ ("$bigint", `String s) ]
  | `Map l ->
      `Assoc
        [
          ( "$map",
            `List (List.map (fun (k, v) -> `List [ tagged k; tagged v ]) l) );
        ]
  | `Set l -> `Assoc [ ("$set", `List (List.map tagged l)) ]

let state_json (s : W.Instance.state) =
  let status =
    match s.status with
    | Queued -> "queued"
    | Running -> "running"
    | Paused -> "paused"
    | Errored -> "errored"
    | Terminated -> "terminated"
    | Complete -> "complete"
    | Waiting -> "waiting"
    | Waiting_for_pause -> "waiting_for_pause"
    | Unknown -> "unknown"
  in
  `Assoc
    [
      ("status", `String status);
      ( "error",
        match s.error with
        | None -> `Null
        | Some (name, message) ->
            `Assoc [ ("name", `String name); ("message", `String message) ] );
      ("output", Option.fold s.output ~none:`Null ~some:tagged);
      ("has_output", `Bool (s.output <> None));
    ]

let handle req env _ctx =
  let url = Request.url req in
  let arg name = URL.query url name in
  let need name = Option.value (arg name) ~default:"" in
  let int_arg name = Option.map int_of_string (arg name) in
  let duration_arg name = Option.map W.Duration.ms (int_arg name) in
  let retention () =
    match (duration_arg "success", duration_arg "error") with
    | None, None -> None
    | success, error -> Some (W.retention ?success ?error ())
  in
  let flow () = W.of_env env (Option.value (arg "binding") ~default:"FLOW") in
  let instance () = W.get (flow ()) (need "id") in
  let json j = Some (Response.text (Jsonkit.to_string j)) in
  let guarded f =
    match f () with
    | r -> r
    | exception Invalid_argument m ->
        Some (Response.text ("Invalid_argument " ^ m))
    | exception Js_error e ->
        Some (Response.text ~status:`Bad_Gateway (Promise.error_to_string e))
  in
  let path = URL.path url in
  if not (String.starts_with ~prefix:"/workflow/" path) then None
  else
    guarded (fun () ->
        match path with
        | "/workflow/create" ->
            let i =
              W.create ?id:(arg "id") ?params:(params_of url)
                ?retention:(retention ()) (flow ())
            in
            json (`String (W.Instance.id i))
        | "/workflow/create_batch" ->
            let options =
              String.split_on_char ',' (need "ids")
              |> List.map (fun id -> W.options ~id ?params:(params_of url) ())
            in
            let created, errors = W.create_batch (flow ()) options in
            json
              (`Assoc
                 [
                   ( "created",
                     `List
                       (List.map (fun i -> `String (W.Instance.id i)) created)
                   );
                   ( "errors",
                     `List
                       (List.map
                          (fun (e : W.batch_error) ->
                            `Assoc
                              [
                                ("index", `Int e.index);
                                ( "id",
                                  match e.id with
                                  | Some id -> `String id
                                  | None -> `Null );
                                ("code", `Int e.code);
                              ])
                          errors) );
                 ])
        | "/workflow/get" -> json (`String (W.Instance.id (instance ())))
        | "/workflow/status" ->
            json (state_json (W.Instance.status (instance ())))
        | "/workflow/pause" ->
            W.Instance.pause (instance ());
            json `Null
        | "/workflow/resume" ->
            W.Instance.resume (instance ());
            json `Null
        | "/workflow/terminate" ->
            W.Instance.terminate
              ?rollback:(Option.map bool_of_string (arg "rollback"))
              (instance ());
            json `Null
        | "/workflow/restart" ->
            let from =
              Option.map
                (fun name ->
                  W.Instance.restart_from ?count:(int_arg "count")
                    ?kind:
                      (Option.map
                         (function
                           | "do" -> W.Instance.Do
                           | "sleep" -> W.Instance.Sleep
                           | _ -> W.Instance.Wait_for_event)
                         (arg "kind"))
                    name)
                (arg "from")
            in
            W.Instance.restart ?from (instance ());
            json `Null
        | "/workflow/delete" ->
            W.Instance.delete (instance ());
            json `Null
        | "/workflow/create_batch_count" ->
            let created, errors =
              W.create_batch_count ?params:(params_of url)
                ?retention:(retention ()) (flow ())
                ~count:(Option.value (int_arg "count") ~default:0)
            in
            json
              (`Assoc
                 [
                   ( "created",
                     `List
                       (List.map (fun i -> `String (W.Instance.id i)) created)
                   );
                   ("errors", `Int (List.length errors));
                 ])
        | "/workflow/delete_batch" ->
            let ids =
              List.filter (( <> ) "") (String.split_on_char ',' (need "ids"))
            in
            let deleted, errors = W.delete_batch (flow ()) ids in
            json
              (`Assoc
                 [
                   ("deleted", `List (List.map (fun id -> `String id) deleted));
                   ( "errors",
                     `List
                       (List.map
                          (fun (e : W.delete_error) ->
                            `Assoc
                              [
                                ("id", `String e.failed_id);
                                ("code", `Int e.failed_code);
                              ])
                          errors) );
                 ])
        | "/workflow/send_event" ->
            W.Instance.send_event (instance ()) ~type_:(need "type")
              (Option.value (value_arg url "payload") ~default:`Null);
            json `Null
        | "/workflow/of_env_error" -> (
            match W.of_env env (need "binding") with
            | _ -> json (`String "ok")
            | exception Invalid_argument m -> json (`String m))
        | _ -> None)
