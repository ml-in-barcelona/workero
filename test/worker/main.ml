let handlers =
  [
    Routes_stream.handle;
    Routes_form.handle;
    Routes_ws.handle;
    Routes_context.handle;
    Routes_globals.handle;
    Routes_env.handle;
    Routes_fetcher.handle;
    Routes_do.handle;
  ]

let handler req env ctx =
  match List.find_map (fun h -> h req env ctx) handlers with
  | Some res -> res
  | None -> Routes_http.handle req env ctx

let () = Workero.serve handler
