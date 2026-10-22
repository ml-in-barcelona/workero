open Workero

let router =
  Router.make
    [
      Router.get "/" (fun _ _ _ _ -> Response.text "home\n");
      Router.get "/about" (fun _ _ _ _ -> Response.text "about\n");
      Router.get "/users/:id<int>" (fun params _ _ _ ->
          Response.text ("user " ^ Router.param_exn params "id" ^ "\n"));
      Router.get "/files/:path<string...>" (fun params _ _ _ ->
          Response.text ("file " ^ Router.param_exn params "path" ^ "\n"));
      Router.post "/echo" (fun _ req _ _ -> Response.text (Request.text req));
    ]

let () = Workero.serve (Router.to_handler router)
