let () =
  List.iter
    (fun name ->
      Workero.Entrypoint.register ~rpc:[ "ping" ] name (fun _ _ ->
          Workero.Entrypoint.make ~rpc:(fun _ _ -> `Null) ()))
    [ "Beta"; "Alpha"; "class" ]
