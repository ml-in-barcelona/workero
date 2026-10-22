let () =
  List.iter
    (fun name ->
      Workero.Durable_object.register name (fun _ _ ->
          Workero.Durable_object.make ()))
    [ "Beta"; "class"; "WorkeroDurableObject"; "Error" ];
  Workero.Durable_object.register ~rpc:[ "increment"; "get" ] "Alpha"
    (fun _ _ -> Workero.Durable_object.make ())
