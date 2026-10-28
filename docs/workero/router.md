
# Router

Use [`Workero.Router`](./Workero-Router.md) to dispatch HTTP requests by method and path. A route handler receives path parameters, the request, `env` and `ctx`, in that order. Use [`Workero.serve`](./Workero.md#val-serve) to register the finished router.


## Route requests

Put this in `src/main.ml` of a [Worker project](./getting_started.md):

```ocaml
open Workero

let router =
  Router.make
    (Router.scope "/api"
       [
         Router.get "/users/me" (fun _ _ _ _ -> Response.text "me\n");
         Router.get "/users/:id<int>" (fun params _ _ _ ->
             Response.text ("user " ^ Router.param_exn params "id" ^ "\n"));
         Router.post "/users/:id<int>" (fun params req _ _ ->
             Response.text
               (Router.param_exn params "id" ^ ": " ^ Request.text req));
         Router.get "/files/:rest<string...>" (fun params _ _ _ ->
             Response.text ("file " ^ Router.param_exn params "rest" ^ "\n"));
       ])

let () = Workero.serve (Router.to_handler router)
```
Run `opam exec -- wrangler dev` in the project, then try these requests:

```sh
curl http://localhost:8787/api/users/me
curl http://localhost:8787/api/users/42
curl -d hello http://localhost:8787/api/users/42
curl http://localhost:8787/api/files/a/b%20c
```
The response bodies are `me`, `user 42`, `42: hello` and `file a/b c`, respectively. The first route wins over the parameter route because a static segment is more specific. [`Workero.Router.param`](./Workero-Router.md#val-param) returns `None` for a missing name. [`Workero.Router.param_exn`](./Workero-Router.md#val-param_exn) raises `Invalid_argument` instead.


## Match paths and methods

- A static segment matches decoded text. For example, `/café` matches `/caf%C3%A9`.
- `:id<string>` matches one segment. `:id<int>` accepts decimal integers, including a leading minus sign. `:ok<bool>` accepts `true` or `false`. A module path ending in `.t`, such as `:id<Note_id.t>`, matches like `string`. These parameters still return strings.
- `:rest<string...>` matches one or more remaining segments and must be last. Its value joins the decoded segments with `/`. It does not match `/files` in the example.
- [`Workero.Router.get`](./Workero-Router.md#val-get), [`Workero.Router.post`](./Workero-Router.md#val-post), [`Workero.Router.put`](./Workero-Router.md#val-put), [`Workero.Router.patch`](./Workero-Router.md#val-patch), [`Workero.Router.delete`](./Workero-Router.md#val-delete), [`Workero.Router.head`](./Workero-Router.md#val-head) and [`Workero.Router.options`](./Workero-Router.md#val-options) match their named method. [`Workero.Router.any`](./Workero-Router.md#val-any) matches any method only if no route for that method matches the path. `HEAD` does not use a `GET` route as a fallback.
[`Workero.Router.scope`](./Workero-Router.md#val-scope) prefixes every route. A child route at `/` under the `/api` scope matches `/api`, not `/api/`. Nest `scope` calls to mount route groups under longer prefixes. Use [`Workero.Router.wrap`](./Workero-Router.md#val-wrap) to apply a function of type `[Router.handler -> Router.handler]` to every route in a group.


## Handle misses and invalid paths

[`Workero.Router.to_handler`](./Workero-Router.md#val-to_handler) sends `404 Not Found` when no route matches. For a path that belongs to another method, it sends `405 Method Not Allowed` with an `Allow` header, except for `HEAD`, `OPTIONS` and `TRACE`, which get `404`. A bad path or a value that does not parse for the selected typed route gets `400`. The router rejects an encoded slash (`%2F`), invalid UTF-8, malformed escapes, dot segments and control characters. A plus sign remains `+`.

By default, a request for `/api/users/42/?q=1` gets a `308` redirect to `/api/users/42?q=1`. Set `~trailing_slash:`Reject` on [`Workero.Router.make`](./Workero-Router.md#val-make) to use `404` instead. Supply `~not_found` to use your own handler for misses. The route functions (`get`, `post`, [`Workero.Router.any`](./Workero-Router.md#val-any) and the others) and [`Workero.Router.scope`](./Workero-Router.md#val-scope) raise `Invalid_argument` for an invalid pattern. [`Workero.Router.make`](./Workero-Router.md#val-make) raises it for duplicate or equally specific overlapping routes. It does not choose one based on declaration order.

For a lookup without an HTTP response, use [`Workero.Router.find`](./Workero-Router.md#val-find) with a raw, percent-encoded path without a query. Unlike `to_handler`, `find` does not redirect trailing slashes. See the [`Workero.Router`](./Workero-Router.md) reference for pattern syntax, result variants and router options.
