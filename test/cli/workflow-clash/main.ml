let () =
  Workero.Workflow.register "Same" (fun _ _ _ -> `Null);
  Workero.Durable_object.register "Same" (fun _ _ ->
      Workero.Durable_object.make ())
