let handlers = [ Routes_stream.handle; Routes_form.handle; Routes_ws.handle ]

let handler req env ctx =
  match List.find_map (fun h -> h req env ctx) handlers with
  | Some res -> res
  | None -> Routes_http.handle req env ctx

let () = Workero.serve handler
