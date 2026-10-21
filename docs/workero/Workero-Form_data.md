
# Module `Workero.Form_data`

Parsed `multipart/form-data` and `application/x-www-form-urlencoded` bodies: a JavaScript `FormData`. Get one from [`Request.form_data`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#val-form_data).

Functions that say "Suspends" suspend like [`Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await) and raise [`Js_error`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#exception-Js_error) when the runtime rejects.

```ocaml
type t
```
```ocaml
type file
```
```ocaml
type value = 
  | Text of string
  | File of file
```
```ocaml
val get : t -> string -> value option
```
First entry with this name.

```ocaml
val get_all : t -> string -> value list
```
```ocaml
val to_list : t -> (string * value) list
```
Entries in the order sent, duplicates kept.

```ocaml
val file_name : file -> string
```
```ocaml
val file_type : file -> string
```
The part's `content-type`; `""` when absent.

```ocaml
val file_size : file -> int
```
```ocaml
val file_bytes : file -> string
```
Reads the whole file. Suspends.

```ocaml
val file_stream : file -> Stream.t
```
```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```