
# Cache

Cache an eligible response in the data center that runs the Worker with [`Workero.Cache`](./Workero-Cache.md). This API uses the global `caches.default`, not an `env` binding. It stores a response under a URL string. Each data center has its own cache.


## Configure

No `wrangler.toml` binding or remote resource creation is needed. Use an absolute URL as the cache key. The example below uses the incoming request URL and caches a successful response from a public origin.


## Write the Worker

```ocaml
let handler req _env ctx =
  let open Workero in
  let key = URL.to_string (Request.url req) in
  match Request.method_ req with
  | GET -> (
      match Cache.match_ key with
      | Some cached -> cached
      | None ->
          let upstream = fetch "https://example.com/" in
          let control = Response.header upstream "cache-control" in
          if Response.status upstream <> 200
             || Response.header_all upstream "set-cookie" <> []
             || control <> None
             || Response.header upstream "vary" <> None
          then upstream
          else
            let headers =
              ("cache-control", "public, max-age=60") :: Response.headers upstream
            in
            let response = Response.copy ~headers upstream in
            Context.wait_until ctx (fun () -> Cache.put key (Response.clone response));
            response)
  | _ -> Response.text ~status:`Method_Not_Allowed "method not allowed\n"

let () = Workero.serve handler
```
The example keeps the upstream status, body and headers. `Response.copy` makes the upstream response writable while preserving its status and headers; `Response.clone` gives `Cache.put` a separate body, so the client can read the returned response. The example does not cache a non-200 response, a response with `Set-Cookie`, an existing `Cache-Control` policy, or a `Vary` header. For a different origin, set a cache policy only when its response is safe to share.

`Cache.put` uses `Cache-Control` to decide whether and how long to store a response. It rejects status 206 and `Vary: *`; a `Set-Cookie` response is not cached. A resolved `Cache.put` promise does not by itself prove that the entry was stored. `Cache.match_` returns `None` for a miss; `Cache.delete` returns `false` if no entry existed. See [`Workero.Cache`](./Workero-Cache.md) and the [Cloudflare Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/).


## Verify locally

Run `wrangler dev` in one terminal. In a second terminal:

```sh
curl -i http://localhost:8787/
curl -i http://localhost:8787/
```
Both requests return the origin's status, body and headers. If the origin returns an eligible 200 response without `Cache-Control`, the response also has `Cache-Control: public, max-age=60`. If it returns an existing cache policy or an ineligible response, the Worker passes that response through unchanged. Local cache behavior may differ from a deployed data center; these requests do not prove a production cache hit. Deploy only after you have set a suitable cache policy for your origin. See the [Cloudflare Cache API example](https://developers.cloudflare.com/workers/examples/cache-api/) for deployment patterns. Cloudflare documents functional Cache API operations for Workers on custom domains. Check the cache on a custom domain or route, not on a `*.workers.dev` hostname. See [Getting started](./getting_started.md) for deployment steps.
