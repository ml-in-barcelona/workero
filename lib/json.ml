type t = Jsonkit.t

let content_type = "content-type"

let has_content_type headers =
  List.exists
    (fun (name, _) -> String.equal (String.lowercase_ascii name) content_type)
    headers

let response ?status ?(headers = []) json =
  let headers =
    if has_content_type headers then headers
    else (content_type, "application/json; charset=utf-8") :: headers
  in
  Response.text ?status ~headers (Jsonkit.to_string json)

let error ?(status = 400) message =
  response ~status (`Assoc [ ("error", `String message) ])

let request req = Jsonkit.of_string (Request.text req)

let parse req =
  match request req with
  | json -> Ok json
  | exception Jsonkit.Of_string_error message -> Error message

let decode of_json req =
  match parse req with
  | Error _ as e -> e
  | Ok json -> (
      match of_json json with
      | value -> Ok value
      | exception Jsonkit.Of_json_error e ->
          Error (Jsonkit.of_json_error_to_string e))
