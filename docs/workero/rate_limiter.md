
# Rate limiting

[`Workero.Rate_limiter`](./Workero-Rate_limiter.md) is the [Workers Rate Limiting](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/) binding. The limit and the period belong to the binding, not to the code.


## Configure

`namespace_id` is a number that you pick. Bindings with the same `namespace_id` share their counters:

```toml
[[ratelimits]]
name = "LIMITER"
namespace_id = "1001"
simple = { limit = 100, period = 60 }
```
`period` is 10 or 60 seconds.


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


## Test

The binding is not available in a plain `workerd` configuration. The tests of workero use a stub that implements `limit` and wraps it as a binding. See `test/worker/services/limiter.mjs`.
