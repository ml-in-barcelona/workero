
# Module `Workero.Cache`

The global `caches.default` runtime API, not an `env` binding. Entries are keyed by URL string in the data center that runs the Worker. Operations suspend like [`Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await) and raise [`Js_error`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#exception-Js_error) when the runtime rejects.

```ocaml
val match_ : string -> Response.t option
```
`match_ url` is the cached response for `url`, or `None`.

```ocaml
val put : string -> Response.t -> unit
```
`put url response` attempts to cache `response` under `url`. The runtime consumes its body; pass [`Response.clone`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-clone) if you also send the response to the client. A resolved call does not guarantee that the response was stored. The Cache API respects `Cache-Control`, does not cache `Set-Cookie` responses, and rejects status 206 or `Vary: *`.

```ocaml
val delete : string -> bool
```
`delete url` removes the entry. It is `false` when there was none.
