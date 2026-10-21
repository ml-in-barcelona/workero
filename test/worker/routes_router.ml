open Workero

let text body = Response.text body

let router =
  Router.make
    (Router.scope "/router"
       [
         Router.get "/users/:id<int>" (fun params _ _ _ ->
             text ("user " ^ Router.param_exn params "id"));
         Router.get "/users/me" (fun _ _ _ _ -> text "me");
         Router.post "/users/:id<int>" (fun params req _ _ ->
             text (Router.param_exn params "id" ^ " " ^ Request.text req));
         Router.get "/files/:rest<string...>" (fun params _ _ _ ->
             text ("file " ^ Router.param_exn params "rest"));
         Router.get "/name/:name<string>" (fun params _ _ _ ->
             text ("name " ^ Router.param_exn params "name"));
       ])

let handle req env ctx =
  let path = Request.path req in
  if String.starts_with ~prefix:"/router/" path then
    Some (Router.to_handler router req env ctx)
  else None
