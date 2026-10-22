let () =
  List.iter
    (fun name ->
      Workero.Durable_object.register name (fun _ _ ->
          Workero.Durable_object.make ()))
    [ "Beta"; "Alpha"; "class"; "WorkeroDurableObject"; "Error" ]
