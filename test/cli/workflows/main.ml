let () =
  List.iter
    (fun name -> Workero.Workflow.register name (fun _ _ _ -> `Null))
    [ "Beta"; "Alpha"; "class" ]
