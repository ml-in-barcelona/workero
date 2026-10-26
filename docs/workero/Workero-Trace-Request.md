
# Module `Trace.Request`

The request of a fetch invocation.

```ocaml
type t
```
```ocaml
val url : t -> string
```
Redacted by default; see [`unredacted`](./#val-unredacted). A string, not [`Workero.URL.t`](./Workero-URL.md#type-t): a redacted URL may not parse.

```ocaml
val method_ : t -> string
```
```ocaml
val headers : t -> (string * string) list
```
Redacted by default; see [`unredacted`](./#val-unredacted).

```ocaml
val cf : t -> Cf.t
```
The tail copy of `request.cf`. It has fewer properties than the request the producer saw, so most accessors give `None`.

```ocaml
val unredacted : t -> t
```
The request with the raw URL and headers, like `getUnredacted()`.
