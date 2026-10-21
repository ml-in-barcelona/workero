let () = prerr_endline "context before the failure"
let () = failwith "boom at init"
let () = Workero.serve (fun _ _ _ -> Workero.Response.text "unreachable")
