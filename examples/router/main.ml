let handler req _env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" -> Response.text "home\n"
  | GET, "/about" -> Response.text "about\n"
  | POST, "/echo" -> Response.text (Request.text req)
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
