
# Rate limiting

[`Workero.Rate_limiter`](./Workero-Rate_limiter.md) is the [Workers Rate Limiting](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/) binding. The limit and the period belong to the binding, not to the code.


## Configure

`namespace_id` is a string containing a positive integer unique to your account. Bindings with the same `namespace_id` share counters for a given key, even across Workers:

```toml
[[ratelimits]]
name = "LIMITER"
namespace_id = "1001"
simple = { limit = 100, period = 60 }
```
`period` is 10 or 60 seconds. This binding requires Wrangler 4\.36.0 or later.


## Use

```ocaml
let handler req env _ctx =
  let open Workero in
  let limiter = Rate_limiter.of_env env "LIMITER" in
  let key = Option.value (Request.header req "cf-connecting-ip") ~default:"anonymous" in
  if Rate_limiter.limit limiter key then Response.text "ok\n"
  else Response.text ~status:`Too_Many_Requests "slow down\n"

let () = Workero.serve handler
```
- [`Workero.Rate_limiter.of_env`](./Workero-Rate_limiter.md#val-of_env) opens the binding. It raises `Invalid_argument` when there is no such binding, or when the binding has no `limit` method.
- [`Workero.Rate_limiter.limit`](./Workero-Rate_limiter.md#val-limit) counts one request for the key and returns `true` when it is allowed. Choose a key that identifies who you limit, such as a user id or an IP address, not the whole URL.
The count is local to the location that runs the Worker and is eventually consistent, so treat the limit as approximate.


## Verify and deploy

Run `wrangler dev` and request `/` repeatedly with the same `cf-connecting-ip` header. After the configured limit in one period, expect status 429\. Wrangler simulates Rate Limiting locally; it does not connect to remote rate counters. Deploy with `wrangler deploy` and repeat the check on the deployed Worker with one key. Results can differ by location because the counters are approximate and local to a Cloudflare location. Plain `workerd` tests in this repository use a stub in `test/worker/services/limiter.mjs`, not Cloudflare's rate counters. See [Rate Limiting bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/) and [local binding support](https://developers.cloudflare.com/workers/local-development/bindings-per-env/).
