
# Cache

[`Workero.Cache`](./Workero-Cache.md) is the [Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/) of the data center that runs the Worker (`caches.default`). It needs no binding. Entries are keyed by URL string, and each data center has its own cache.

```ocaml
let url = "https://example.com/data.json"

let handler _req _env ctx =
  let open Workero in
  match Cache.match_ url with
  | Some cached -> cached
  | None ->
      let upstream = fetch url in
      let body = Response.body_bytes upstream in
      let headers = [ ("cache-control", "max-age=60") ] in
      Context.wait_until ctx (fun () ->
          Cache.put url (Response.bytes ~headers body));
      Response.bytes ~headers body

let () = Workero.serve handler
```
- [`Workero.Cache.match_`](./Workero-Cache.md#val-match_) gives `Some response` for a URL, or `None`.
- [`Workero.Cache.put`](./Workero-Cache.md#val-put) caches a response. The runtime reads the body of the response you give it, so send the client a different [`Workero.Response.t`](./Workero-Response.md#type-t) made from the same bytes, as the sample does. It rejects a response with status 206 or a `Vary: *` header. It keeps the entry only as long as the `cache-control` header allows, so set `max-age`.
- [`Workero.Cache.delete`](./Workero-Cache.md#val-delete) removes an entry. It gives `false` when there was none.
The cache is not shared between data centers. On a `*.workers.dev` domain, the Cache API does not store anything. Use a [custom domain](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/) to see it work in production. In `wrangler dev`, it works locally.
