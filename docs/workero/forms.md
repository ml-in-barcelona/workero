
# Forms and file uploads

[`Workero.Request.form_data`](./Workero-Request.md#val-form_data) reads a `multipart/form-data` or `application/x-www-form-urlencoded` body. It gives a [`Workero.Form_data.t`](./Workero-Form_data.md#type-t).

```ocaml
let handler req _env _ctx =
  let open Workero in
  match Request.form_data req with
  | form -> (
      match Form_data.get form "avatar" with
      | Some (File file) ->
          Response.text
            (Printf.sprintf "%s: %d bytes\n" (Form_data.file_name file)
               (Form_data.file_size file))
      | Some (Text _) -> Response.text ~status:400 "avatar must be a file\n"
      | None -> Response.text ~status:400 "no avatar\n")
  | exception Js_error _ -> Response.text ~status:400 "not a form\n"

let () = Workero.serve handler
```
[`Workero.Request.form_data`](./Workero-Request.md#val-form_data) raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when the content type is neither of the two, or when the body is malformed.


## Values

A field is a [`Workero.Form_data.value`](./Workero-Form_data.md#type-value): `Text of string` or `File of file`.

- [`Workero.Form_data.get`](./Workero-Form_data.md#val-get) gives the first entry with a name.
- [`Workero.Form_data.get_all`](./Workero-Form_data.md#val-get_all) gives all entries with a name.
- [`Workero.Form_data.to_list`](./Workero-Form_data.md#val-to_list) gives all entries in the order sent. Duplicate names stay.

## Files

- [`Workero.Form_data.file_name`](./Workero-Form_data.md#val-file_name) is the file name that the client sent.
- [`Workero.Form_data.file_type`](./Workero-Form_data.md#val-file_type) is the `content-type` of the part, or `""`.
- [`Workero.Form_data.file_size`](./Workero-Form_data.md#val-file_size) is the size in bytes.
- [`Workero.Form_data.file_bytes`](./Workero-Form_data.md#val-file_bytes) reads the whole file into a `string`.
- [`Workero.Form_data.file_stream`](./Workero-Form_data.md#val-file_stream) gives the file as a [`Workero.Stream.t`](./Workero-Stream.md#type-t). Use it to write a large file to [R2](./r2.md) without loading it.

## Limit

The runtime parses the whole body before it gives you the form, so an upload is in memory. [`Workero.Form_data.file_stream`](./Workero-Form_data.md#val-file_stream) only reads from that copy. To handle an upload that does not fit in memory, read [`Workero.Request.body`](./Workero-Request.md#val-body) in chunks. See [Streams](./streams.md).
