open Jsonkit.Primitives

type user = { name : string; age : int } [@@deriving json]

let handler req _env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | POST, "/json" -> (
      match Workero_json.parse req with
      | Ok json -> Workero_json.response json
      | Error message -> Workero_json.error message)
  | POST, "/user" -> (
      match Workero_json.decode user_of_json req with
      | Ok user -> Workero_json.response (user_to_json user)
      | Error message -> Workero_json.error ~status:422 message)
  | POST, "/raise" -> Workero_json.response (Workero_json.request req)
  | GET, "/custom" ->
      Workero_json.response ~status:201
        ~headers:[ ("Content-Type", "application/vnd.api+json"); ("x-a", "b") ]
        (`List [ `Int 1; `Null ])
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
