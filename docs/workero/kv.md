
# KV

[`Workero.KV`](./Workero-KV.md) is a [Workers KV](https://developers.cloudflare.com/kv/) namespace: a global key-value store with text values.


## Configure

```sh
npx wrangler kv namespace create KV
```
Copy the printed `id` into `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "KV"
id = "<namespace id>"
```

## Use

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
      | None -> Response.text ~status:404 "not found\n")
  | PUT, "/kv" ->
      KV.put ~expiration_ttl:3600 kv key (Request.text req);
      Response.text "stored\n"
  | DELETE, "/kv" ->
      KV.delete kv key;
      Response.text "deleted\n"
  | GET, "/keys" ->
      let prefix = URL.query url "prefix" in
      Response.text (String.concat "\n" (KV.list ?prefix kv) ^ "\n")
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
```
- [`Workero.KV.of_env`](./Workero-KV.md#val-of_env) opens the namespace bound as `"KV"`. It raises `Invalid_argument` when there is no such binding.
- [`Workero.KV.get`](./Workero-KV.md#val-get) gives `Some value`, or `None` when the key does not exist.
- [`Workero.KV.put`](./Workero-KV.md#val-put) stores a value. `~expiration_ttl` is a number of seconds. Cloudflare requires at least 60\.
- [`Workero.KV.delete`](./Workero-KV.md#val-delete) removes a key. A missing key is not an error.
- [`Workero.KV.list`](./Workero-KV.md#val-list) gives the names of all keys that start with `~prefix`, in lexicographic order. KV returns at most 1000 keys for each request. `list` follows the cursor until the listing is complete, so a large namespace takes several requests and its names are all held in memory. It raises `Failure "Workero.KV.list: ..."` when KV reports an incomplete page.
Values are text. KV is eventually consistent: a change can take up to 60 seconds to show in other locations.


## Test locally

```sh
npx wrangler dev
curl -X PUT -d hello "localhost:8787/kv?k=greeting"
curl "localhost:8787/kv?k=greeting"
```