
# Module `Workero.URL`

An absolute `http` or `https` URL, parsed by `Js_of_ocaml.Url`. Paths and query arguments are percent-decoded. In a query, `+` decodes to a space, as in WHATWG `URLSearchParams`.

```ocaml
type t
```
```ocaml
val of_string : string -> t option
```
`None` when the string is not an `http` or `https` URL.

```ocaml
val to_string : t -> string
```
```ocaml
val scheme : t -> string
```
```ocaml
val host : t -> string
```
The host name, without port.

```ocaml
val port : t -> int
```
The port, or 80 or 443 when the URL has none.

```ocaml
val path : t -> string
```
The decoded path, starting with `"/"`. The query string and fragment are not part of it.

```ocaml
val query : t -> string -> string option
```
`query url name` is the first decoded value of `name`.

```ocaml
val query_all : t -> string -> string list
```
All decoded values of `name`, in order.

```ocaml
val query_args : t -> (string * string) list
```
All decoded `(name, value)` pairs, in order.
