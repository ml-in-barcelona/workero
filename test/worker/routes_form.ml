open Workero

let bytes_text s =
  String.to_seq s |> List.of_seq
  |> List.map (fun c -> string_of_int (Char.code c))
  |> String.concat ","

let streamed_length file =
  let total = ref 0 in
  Stream.iter
    (fun chunk -> total := !total + String.length chunk)
    (Form_data.file_stream file);
  !total

let describe (name, value) =
  match value with
  | Form_data.Text s -> Printf.sprintf "%s=text:%S" name s
  | File f ->
      Printf.sprintf "%s=file name=%S type=%S size=%d bytes=%s streamed=%d" name
        (Form_data.file_name f) (Form_data.file_type f) (Form_data.file_size f)
        (bytes_text (Form_data.file_bytes f))
        (streamed_length f)

let dump req =
  match Request.form_data req with
  | form ->
      let first =
        match Form_data.get form "title" with
        | Some (Text s) -> s
        | Some (File _) -> "<file>"
        | None -> "<none>"
      in
      let all =
        Form_data.get_all form "title"
        |> List.map (function Form_data.Text s -> s | File _ -> "<file>")
      in
      Response.text
        (String.concat "\n"
           (List.map describe (Form_data.to_list form)
           @ [ "first=" ^ first; "all=" ^ String.concat "|" all ]))
  | exception Js_error _ -> Response.text ~status:`Bad_Request "not a form"

let handle req _env _ctx =
  match URL.path (Request.url req) with
  | "/form/dump" -> Some (dump req)
  | _ -> None
