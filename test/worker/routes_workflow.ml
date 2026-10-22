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
        (fun { attempt } ->
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
      let payload = S.wait_for_event step "approval" ~type_:"approve" in
      `Assoc [ ("approved", payload) ]
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
      let sent = S.wait_for_event step "go" ~type_:"go" in
      `Assoc
        [ ("step", step_result); ("payload", event.payload); ("event", sent) ]
  | "undefined" ->
      let step_result = S.do_ step "undefined" (fun _ -> `Undefined) in
      let sent = S.wait_for_event step "go" ~type_:"go" in
      `Assoc [ ("step", step_result); ("event", sent) ]
  | "fail" -> failwith "run failed"
  | other -> invalid_arg ("unknown scenario " ^ other)

let () = W.register "Flow" run

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
            let i = W.create ?id:(arg "id") ?params:(params_of url) (flow ()) in
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
            W.Instance.terminate (instance ());
            json `Null
        | "/workflow/restart" ->
            W.Instance.restart (instance ());
            json `Null
        | "/workflow/send_event" ->
            W.Instance.send_event (instance ()) ~type_:(need "type")
              (Option.value (value_arg url "payload") ~default:`Null);
            json `Null
        | "/workflow/of_env_error" -> (
            match W.of_env env (need "binding") with
            | _ -> json (`String "ok")
            | exception Invalid_argument m -> json (`String m))
        | _ -> None)
