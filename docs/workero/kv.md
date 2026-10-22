
# KV

Store and list text values by key with [`Workero.KV`](./Workero-KV.md), the supported subset of [Workers KV](https://developers.cloudflare.com/kv/). KV is eventually consistent across locations. Changes often become visible elsewhere within 60 seconds, but 60 seconds is not a guaranteed upper bound.


## Configure the binding

For local development, put this in `wrangler.toml`. Wrangler creates local storage when you run `npx wrangler dev`:

```toml
[[kv_namespaces]]
binding = "KV"
```

## Write the Worker

```ocaml
let handler req env _ctx =
  let open Workero in
  let kv = KV.of_env env "KV" in
  let url = Request.url req in
  let key = Option.value (URL.query url "k") ~default:"" in
  match (Request.method_ req, URL.path url) with
  | GET, "/kv" -> (
      match KV.get kv key with
      | Some value -> Response.text value
      | None -> Response.text ~status:`Not_Found "not found\n")
  | PUT, "/kv" ->
      KV.put ~expiration_ttl:3600 kv key (Request.text req);
      Response.text "stored\n"
  | DELETE, "/kv" ->
      KV.delete kv key;
      Response.text "deleted\n"
  | GET, "/keys" ->
      let prefix = URL.query url "prefix" in
      Response.text (String.concat "\n" (KV.list ?prefix kv) ^ "\n")
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
`KV.get` returns `None` for a missing key. `KV.put` takes text and an optional expiration time in seconds (at least 60\). `KV.delete` accepts a missing key. `KV.list` returns names in lexicographic order. It follows cursors across pages of at most 1000 keys and holds all names in memory. It raises `Failure` if KV reports an incomplete page without a cursor. See [`Workero.KV`](./Workero-KV.md) for the API.


## Verify locally

Run `npx wrangler dev` in one terminal. In a second terminal:

```sh
curl -X PUT -d hello "http://localhost:8787/kv?k=greeting"
curl "http://localhost:8787/kv?k=greeting"
curl "http://localhost:8787/keys?prefix=greet"
```
The responses are `stored`, `hello` and `greeting`, in that order.


## Deploy with an existing namespace

Remote creation requires an authenticated Wrangler. If you do not let [Wrangler provision it on deploy](https://developers.cloudflare.com/workers/wrangler/configuration/#automatic-provisioning), create a namespace and copy its printed ID into `wrangler.toml`:

```sh
npx wrangler kv namespace create KV
```
```toml
[[kv_namespaces]]
binding = "KV"
id = "<namespace id>"
```
See [Cloudflare KV setup](https://developers.cloudflare.com/kv/get-started/) and [listing keys](https://developers.cloudflare.com/kv/api/list-keys/). See [Getting started](./getting_started.md) for deployment steps.
