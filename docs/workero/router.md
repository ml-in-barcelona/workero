
# Router

[`Workero.Router`](./Workero-Router.md) picks a handler from the method and the path of a request. It adds path parameters, catch-all paths and `405` answers to a plain `match` on [`Workero.Request.method_`](./Workero-Request.md#val-method_) and [`Workero.Request.path`](./Workero-Request.md#val-path).

```ocaml
open Workero

let router =
  Router.make
    [
      Router.get "/" (fun _ _ _ _ -> Response.text "home\n");
      Router.get "/users/:id<int>" (fun params _ _ _ ->
          Response.text ("user " ^ Router.param_exn params "id" ^ "\n"));
      Router.get "/files/:path<string...>" (fun params _ _ _ ->
          Response.text ("file " ^ Router.param_exn params "path" ^ "\n"));
      Router.post "/echo" (fun _ req _ _ -> Response.text (Request.text req));
    ]

let () = Workero.serve (Router.to_handler router)
```
A handler takes the parameters, the request, the environment and the context. Read a parameter with [`Workero.Router.param`](./Workero-Router.md#val-param) or [`Workero.Router.param_exn`](./Workero-Router.md#val-param_exn).


## Routes

[`Workero.Router.get`](./Workero-Router.md#val-get), [`Workero.Router.post`](./Workero-Router.md#val-post), [`Workero.Router.put`](./Workero-Router.md#val-put), [`Workero.Router.patch`](./Workero-Router.md#val-patch), [`Workero.Router.delete`](./Workero-Router.md#val-delete), [`Workero.Router.head`](./Workero-Router.md#val-head) and [`Workero.Router.options`](./Workero-Router.md#val-options) make a route for one method. [`Workero.Router.any`](./Workero-Router.md#val-any) makes a route for every method; it is tried after the routes of the request method.

[`Workero.Router.scope`](./Workero-Router.md#val-scope) adds a prefix to a list of routes. [`Workero.Router.wrap`](./Workero-Router.md#val-wrap) applies a function on handlers to each route, for example to add a header:

```ocaml
let with_cors handler params req env ctx =
  let res = handler params req env ctx in
  Response.copy res
    ~headers:(("access-control-allow-origin", "*") :: Response.headers res)

let routes =
  Router.scope "/api"
    (Router.wrap with_cors [ Router.get "/ping" (fun _ _ _ _ -> Response.text "pong") ])
```

## Patterns

The pattern syntax is the one of the path patterns of [server-reason-react](https://github.com/ml-in-barcelona/server-reason-react) routes. A pattern is `/`, or segments that each start with `/`.

| Segment | Matches |
| --- | --- |
| `users` | The decoded segment `users`. Allowed characters are letters, digits, `- . _ ~ ! $ & ' ( ) * + , ; = : @` and bytes from 0x80, so `café` matches `caf%C3%A9`. `.` and `..` are not allowed. |
| `:id<string>` | One segment. |
| `:id<int>` | One segment of plain decimal digits, with an optional leading `-`. |
| `:ok<bool>` | `true` or `false`. |
| `:id<Note_id.t>` | One segment. A module path ending in `.t` is accepted and matches like `string`. |
| `:rest<string...>` | At least one segment, up to the end of the path. It must be the last segment. The value is the decoded segments joined with `/`. |
A parameter name starts with a lower case letter or `_` and continues with letters, digits, `_` and `'`. A value that does not parse as an `int` or a `bool` gives `400`. There are no optional segments, and a pattern has no trailing slash.


## Matching

The router splits the raw path first and decodes each segment after, so `%2F` never splits a segment. A path with an encoded slash, a malformed escape, a dot segment such as `%2e%2e`, a control character or invalid UTF-8 gets `400`. `+` stays `+`.

When several routes match, the most specific wins: a static segment beats a parameter, and a pattern without a catch-all beats a catch-all pattern with the same number of static segments. [`Workero.Router.make`](./Workero-Router.md#val-make) raises `Invalid_argument` when a pattern is invalid, when a method and pattern appear twice, and when two patterns of one method could match the same path with the same specificity, such as `/:a<string>/x` and `/x/:b<string>`. The same rules hold in server-reason-react.


## Answers

[`Workero.Router.to_handler`](./Workero-Router.md#val-to_handler) answers these cases itself:

- No route matches: `404` `Not Found`, or the handler of `~not_found`.
- The path matches a route of another method: `405` with an `Allow` header. It is not sent for `HEAD`, `OPTIONS` and `TRACE`. `HEAD` does not fall back to `GET`.
- A bad path or parameter: `400`.
- A path with trailing slashes: `308` to the path without them, with the query kept. `~trailing_slash:`Reject` answers `not_found` instead.
[`Workero.Router.find`](./Workero-Router.md#val-find) does the lookup alone, without a request. Use it to test your routes or to dispatch yourself.
