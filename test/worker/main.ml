let handlers =
  [
    Routes_stream.handle;
    Routes_form.handle;
    Routes_ws.handle;
    Routes_context.handle;
    Routes_globals.handle;
    Routes_crypto.handle;
    Routes_env.handle;
    Routes_fetcher.handle;
    Routes_router.handle;
    Routes_queue.handle;
    Routes_rate_limiter.handle;
    Routes_hyperdrive.handle;
    Routes_ai.handle;
    Routes_analytics.handle;
    Routes_socket.handle;
    Routes_do.handle;
    Routes_entrypoint.handle;
  ]

let handler req env ctx =
  match List.find_map (fun h -> h req env ctx) handlers with
  | Some res -> res
  | None -> Routes_http.handle req env ctx

let () = Workero.serve handler
let () = Workero.queue Routes_queue.consume
let () = Workero.email Routes_email.receive
