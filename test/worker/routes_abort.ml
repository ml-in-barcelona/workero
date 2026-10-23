open Workero

let upstream = "http://upstream.test"
let sleep ms = Promise.await (Timer.sleep ms)
let elapsed_ms since = int_of_float (Date.now () -. since)

let describe exn =
  match exn with
  | Js_error e ->
      Printf.sprintf "raised abort=%b %s"
        (Abort_signal.is_abort exn)
        (Promise.error_to_string e)
  | e -> "raised " ^ Printexc.to_string e

let timed f =
  let t0 = Date.now () in
  let result = try f () with e -> describe e in
  Printf.sprintf "%s fast=%b" result (elapsed_ms t0 < 300)

let status res = Printf.sprintf "status %d" (Response.status res)

let slow_hits () =
  Response.body_text (fetch (upstream ^ "/slow-hits")) |> int_of_string

let fetch_controller () =
  let c = Abort_controller.create () in
  ignore (Timer.set_timeout (fun () -> Abort_controller.abort c) 30);
  timed (fun () ->
      status (fetch ~signal:(Abort_controller.signal c) (upstream ^ "/slow")))

let fetch_reason () =
  let c = Abort_controller.create () in
  Abort_controller.abort ~reason:"because" c;
  timed (fun () ->
      status (fetch ~signal:(Abort_controller.signal c) (upstream ^ "/slow")))

let fetch_timeout () =
  timed (fun () ->
      status (fetch ~signal:(Abort_signal.timeout 40) (upstream ^ "/slow")))

let fetch_unaborted () =
  let c = Abort_controller.create () in
  status (fetch ~signal:(Abort_controller.signal c) (upstream ^ "/echo"))

let fetch_any () =
  let c = Abort_controller.create () in
  let signal =
    Abort_signal.any [ Abort_controller.signal c; Abort_signal.timeout 40 ]
  in
  timed (fun () -> status (fetch ~signal (upstream ^ "/slow")))

let fetch_any_controller () =
  let c = Abort_controller.create () in
  let signal =
    Abort_signal.any [ Abort_controller.signal c; Abort_signal.timeout 2000 ]
  in
  ignore (Timer.set_timeout (fun () -> Abort_controller.abort c) 30);
  timed (fun () -> status (fetch ~signal (upstream ^ "/slow")))

let fetch_body () =
  let c = Abort_controller.create () in
  let res =
    fetch ~signal:(Abort_controller.signal c) (upstream ^ "/slow-body")
  in
  ignore (Timer.set_timeout (fun () -> Abort_controller.abort c) 50);
  timed (fun () -> Response.body_text res)

let fetch_immediate () =
  let before = slow_hits () in
  let result =
    timed (fun () ->
        status
          (fetch ~signal:(Abort_signal.aborted_now ()) (upstream ^ "/slow")))
  in
  sleep 100;
  Printf.sprintf "%s reached=%d" result (slow_hits () - before)

let race () =
  let c = Abort_controller.create () in
  ignore (Timer.set_timeout (fun () -> Abort_controller.abort c) 30);
  timed (fun () ->
      Promise.await
        (Promise.race
           [
             Timer.sleep 1000 |> Promise.map (fun () -> "slept");
             Abort_signal.to_promise (Abort_controller.signal c);
           ]))

let on_abort () =
  let c = Abort_controller.create () in
  let flag = ref "unset" in
  Abort_signal.on_abort (Abort_controller.signal c) (fun () ->
      sleep 20;
      flag := "after await");
  let before = !flag in
  Abort_controller.abort c;
  let right_after = !flag in
  sleep 100;
  Printf.sprintf "before=%s right_after=%s final=%s" before right_after !flag

let on_abort_late () =
  let flag = ref "unset" in
  Abort_signal.on_abort (Abort_signal.aborted_now ()) (fun () ->
      sleep 20;
      flag := "ran");
  sleep 100;
  !flag

let on_abort_once () =
  let c = Abort_controller.create () in
  let runs = ref 0 in
  Abort_signal.on_abort (Abort_controller.signal c) (fun () -> incr runs);
  Abort_controller.abort c;
  Abort_controller.abort c;
  sleep 50;
  string_of_int !runs

let on_abort_raises () =
  let c = Abort_controller.create () in
  Abort_signal.on_abort (Abort_controller.signal c) (fun () ->
      failwith "listener boom");
  Abort_controller.abort c;
  sleep 50;
  "survived"

let state () =
  let c = Abort_controller.create () in
  let s = Abort_controller.signal c in
  let show () =
    Printf.sprintf "aborted=%b reason=%s" (Abort_signal.aborted s)
      (match Abort_signal.reason s with
      | None -> "none"
      | Some e -> Promise.error_to_string e)
  in
  let before = show () in
  let check =
    try
      Abort_signal.throw_if_aborted s;
      "no raise"
    with Js_error _ -> "raised"
  in
  Abort_controller.abort ~reason:"stop" c;
  let after = show () in
  let thrown =
    match Abort_signal.throw_if_aborted s with
    | () -> "no raise"
    | exception (Js_error e as exn) ->
        Printf.sprintf "raised abort=%b %s"
          (Abort_signal.is_abort exn)
          (Promise.error_to_string e)
  in
  String.concat " | " [ before; check; after; thrown ]

let is_abort_other () =
  Printf.sprintf "%b %b"
    (Abort_signal.is_abort (Failure "x"))
    (Abort_signal.is_abort (Js_error (Promise.error_of_string "plain")))

let fetcher_abort env =
  let c = Abort_controller.create () in
  ignore (Timer.set_timeout (fun () -> Abort_controller.abort c) 30);
  timed (fun () ->
      status
        (Fetcher.fetch
           ~signal:(Abort_controller.signal c)
           (Fetcher.of_env env "BACKEND")
           "http://any.host/slow"))

let fetcher_request req env =
  let c = Abort_controller.create () in
  ignore (Timer.set_timeout (fun () -> Abort_controller.abort c) 30);
  let own = Request.signal req in
  let result =
    timed (fun () ->
        status
          (Fetcher.fetch_request
             ~signal:(Abort_controller.signal c)
             (Fetcher.of_env env "BACKEND")
             req))
  in
  Printf.sprintf "%s own_aborted=%b" result (Abort_signal.aborted own)

let fetcher_request_unaborted req env =
  let c = Abort_controller.create () in
  status
    (Fetcher.fetch_request
       ~signal:(Abort_controller.signal c)
       (Fetcher.of_env env "BACKEND")
       req)

let request_signal req =
  Printf.sprintf "aborted=%b" (Abort_signal.aborted (Request.signal req))

let disconnect_state = ref "idle"

let disconnect req ctx =
  disconnect_state := "streaming";
  let stop = ref false in
  Abort_signal.on_abort (Request.signal req) (fun () ->
      stop := true;
      disconnect_state := "signal");
  Response.stream ctx (fun w ->
      try
        while not !stop do
          Stream.Writer.write w "tick\n";
          sleep 20
        done
      with Js_error _ ->
        if !disconnect_state = "streaming" then
          disconnect_state := "write failed")

let handle req env ctx =
  let text s = Some (Response.text s) in
  match URL.path (Request.url req) with
  | "/abort/fetch-controller" -> text (fetch_controller ())
  | "/abort/fetch-reason" -> text (fetch_reason ())
  | "/abort/fetch-timeout" -> text (fetch_timeout ())
  | "/abort/fetch-unaborted" -> text (fetch_unaborted ())
  | "/abort/fetch-any" -> text (fetch_any ())
  | "/abort/fetch-any-controller" -> text (fetch_any_controller ())
  | "/abort/fetch-body" -> text (fetch_body ())
  | "/abort/fetch-immediate" -> text (fetch_immediate ())
  | "/abort/race" -> text (race ())
  | "/abort/on-abort" -> text (on_abort ())
  | "/abort/on-abort-late" -> text (on_abort_late ())
  | "/abort/on-abort-once" -> text (on_abort_once ())
  | "/abort/on-abort-raises" -> text (on_abort_raises ())
  | "/abort/state" -> text (state ())
  | "/abort/is-abort-other" -> text (is_abort_other ())
  | "/abort/fetcher" -> text (fetcher_abort env)
  | "/abort/fetcher-request/slow" -> text (fetcher_request req env)
  | "/abort/fetcher-request/echo" -> text (fetcher_request_unaborted req env)
  | "/abort/disconnect" -> Some (disconnect req ctx)
  | "/abort/disconnect-state" -> text !disconnect_state
  | "/abort/request-signal" -> text (request_signal req)
  | _ -> None
