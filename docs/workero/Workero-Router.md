
# Module `Workero.Router`

Dispatch requests by method and decoded path. See [Router](./router.md) for a complete Worker and expected responses.

```ocaml
type params
```
```ocaml
val param : params -> string -> string option
```
`param params name` is the decoded value of the path parameter `name`, or `None` when the pattern has no such parameter. A catch-all parameter gives its decoded segments joined with `"/"`.

```ocaml
val param_exn : params -> string -> string
```
Like [`param`](./#val-param). Raises `Invalid_argument` when the pattern has no such parameter.

```ocaml
type handler = params -> Request.t -> Env.t -> Context.t -> Response.t
```
```ocaml
type route
```
```ocaml
val get : string -> handler -> route
```
```ocaml
val head : string -> handler -> route
```
```ocaml
val post : string -> handler -> route
```
```ocaml
val put : string -> handler -> route
```
```ocaml
val patch : string -> handler -> route
```
```ocaml
val delete : string -> handler -> route
```
```ocaml
val options : string -> handler -> route
```
```ocaml
val any : string -> handler -> route
```
Every method, tried after the routes of the request method.

```ocaml
val scope : string -> route list -> route list
```
`scope "/api" routes` prefixes every pattern. The prefix follows the pattern syntax; `"/"` adds nothing. A child route at `"/"` matches `"/api"`, not `"/api/"`. Nested scopes mount routes under successive prefixes.

```ocaml
val wrap : (handler -> handler) -> route list -> route list
```
Middleware is a function on handlers. `wrap with_cors routes` applies it to each route. There is no other middleware mechanism.

```ocaml
type t
```
```ocaml
val make : 
  ?not_found:handler ->
  ?trailing_slash:[ `Redirect | `Reject ] ->
  route list ->
  t
```
`make routes` checks the routes and builds the router.

A pattern is `"/"` or a list of segments, each starting with `"/"`:

- A static segment, such as `users`, uses letters, digits and `- . _ ~ ! $ & ' ( ) * + , ; = : @`, or any byte from 0x80. It is matched against the decoded request segment, so `café` matches `caf%C3%A9`. `"."` and `".."` are not allowed.
- `:name<type>` matches one segment. `name` starts with a lower case letter or `"_"` and continues with letters, digits, `"_"` and `"'"`. `type` is `string`, `int`, `bool` or a module path ending in `.t`, such as `Note_id.t`. A value that is not an `int` (plain decimal within the OCaml `int` range) or a `bool` (`true` or `false`) gives [`Bad_request`](./#type-found.Bad_request) when that route wins. A module path is accepted and matches like `string`.
- `:name<string...>` matches the rest of the path, at least one segment, and must be last.
A method-specific route is tried before [`any`](./#val-any). Among those routes, more static segments win; a pattern without a catch-all beats one with a catch-all when they have the same number of static segments. Matching splits the raw path first and decodes each segment after. An encoded slash `%2F` is rejected, not treated as a segment separator.

`not_found` answers when no route matches; it receives empty parameters. `trailing_slash` is ``Redirect` by default: a path with trailing slashes gets a 308 to the path without them, query kept. ``Reject` answers it with `not_found`. The router does not redirect a protocol-relative path.

Raises `Invalid_argument` when a pattern is invalid, when a method and pattern appear twice, or when two patterns for the same method could match the same path with the same specificity, such as `/:a<string>/x` and `/x/:b<string>`.

```ocaml
type found = 
  | Found of handler * params
  | Method_not_allowed of Method.t list
  | Bad_request of string
  | Not_found
```
```ocaml
val find : t -> Method.t -> string -> found
```
`find router meth path` looks up the raw, percent-encoded `path` without a query. It is pure and does not apply `trailing_slash` redirects or call `not_found`. `Bad_request` carries the reason when a segment has a malformed escape, an encoded slash, a dot segment, a control character or invalid UTF-8, when the path is empty, has an empty segment, or when a typed parameter on the selected route does not parse. `Method_not_allowed` lists the methods that match the path; it is never given for `HEAD`, `OPTIONS` or `TRACE`.

```ocaml
val to_handler : t -> Request.t -> Env.t -> Context.t -> Response.t
```
Answers 400, 404 and 405 itself; 405 has an `Allow` header. `HEAD` does not fall back to `GET`. Use as `Workero.serve (Router.to_handler router)`.
