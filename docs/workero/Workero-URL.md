
# Module `Workero.URL`

An absolute `http` or `https` URL, parsed by the JavaScript `URL`. Paths and query arguments are percent-decoded. In a query, `+` decodes to a space, as in WHATWG `URLSearchParams`.

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
The decoded path, starting with `"/"`. The query string and fragment are not part of it. A path with a malformed escape, such as `"%zz"`, is returned undecoded.

```ocaml
val pathname : t -> string
```
The raw path as the JavaScript `pathname`: percent-encoded, so `"%2F"` stays `"%2F"`.

```ocaml
val search : t -> string
```
The query string with its `"?"`, or `""` when there is none. It is not decoded.

```ocaml
val hash : t -> string
```
The fragment with its `"#"`, or `""` when there is none.

```ocaml
val origin : t -> string
```
The scheme, host and port, such as `"https://a.test:8443"`. The port is left out when it is the default.

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
