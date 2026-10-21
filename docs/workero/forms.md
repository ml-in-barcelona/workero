
# Forms and file uploads

Use [`Workero.Request.form_data`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-form_data) to read `multipart/form-data` uploads or `application/x-www-form-urlencoded` fields. This handler checks for an `avatar` file and returns its name and size.

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
      | Some (Text _) -> Response.text ~status:`Bad_Request "avatar must be a file\n"
      | None -> Response.text ~status:`Bad_Request "no avatar\n")
  | exception Js_error _ -> Response.text ~status:`Bad_Request "not a form\n"

let () = Workero.serve handler
```
Run `npx wrangler dev` in one terminal. In a second terminal, send a file:

```sh
printf 'hello' > avatar.txt
curl -F avatar=@avatar.txt http://localhost:8787/
```
The response is `avatar.txt: 5 bytes`. A missing `avatar` or a non-file value gets a 400 response. [`Workero.Request.form_data`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-form_data) raises [`Workero.Js_error`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#exception-Js_error) for an unsupported content type or a malformed form body.


## Read fields

A field is a [`Workero.Form_data.value`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#type-value): `Text of string` or `File of file`.

- [`Workero.Form_data.get`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-get) gives the first entry with a name.
- [`Workero.Form_data.get_all`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-get_all) gives all entries with a name.
- [`Workero.Form_data.to_list`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-to_list) gives all entries in the order sent. Duplicate names stay.

## Read files

- [`Workero.Form_data.file_name`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-file_name) is the file name that the client sent.
- [`Workero.Form_data.file_type`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-file_type) is the `content-type` of the part, or `""`.
- [`Workero.Form_data.file_size`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-file_size) is the size in bytes.
- [`Workero.Form_data.file_bytes`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-file_bytes) reads the whole file into a `string`.
- [`Workero.Form_data.file_stream`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-file_stream) gives the file as a [`Workero.Stream.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/Stream/index.html#type-t). Reading it in chunks avoids creating another whole-file OCaml `string`.

## Multipart memory limit

The platform parses the entire multipart body before [`Workero.Request.form_data`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-form_data) returns. [`Workero.Form_data.file_stream`](https://ml-in-barcelona.github.io/workero/workero/Workero/Form_data/index.html#val-file_stream) does not avoid that buffering. [R2](./r2.md) [`Workero.R2.put`](https://ml-in-barcelona.github.io/workero/workero/Workero/R2/index.html#val-put) accepts a `string`, not a stream. To process a body in chunks, use [`Workero.Request.body`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-body) instead of form parsing. See [Streams](./streams.md) and [Workers memory limits](https://developers.cloudflare.com/workers/platform/limits/#memory).
