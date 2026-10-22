let () =
  Workero.Entrypoint.register "Same" (fun _ _ -> Workero.Entrypoint.make ());
  Workero.Durable_object.register "Same" (fun _ _ ->
      Workero.Durable_object.make ())
