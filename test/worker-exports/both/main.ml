let () = Workero.serve (fun _ _ _ -> Workero.Response.text "served")
let () = Workero.scheduled (fun _ _ _ -> ())
