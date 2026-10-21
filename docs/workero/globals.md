
# Timers, time, and randomness

Use [`Workero.Timer`](./Workero-Timer.md) to wait in a handler, [`Workero.Date`](./Workero-Date.md) to read the wall clock, and [`Workero.Crypto`](./Workero-Crypto.md) to generate random values. This handler waits before returning a random UUID.

```ocaml
let handler _req _env _ctx =
  let open Workero in
  Promise.await (Timer.sleep 100);
  Response.text (Crypto.random_uuid () ^ "\n")

let () = Workero.serve handler
```
Run `npx wrangler dev` in one terminal and `curl http://localhost:8787/` in a second terminal. The response is a version 4 UUID.


## Timers

[`Workero.Timer.sleep`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-sleep), [`Workero.Timer.set_timeout`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-set_timeout), and [`Workero.Timer.set_interval`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-set_interval) take delays in milliseconds. Use [`Workero.Timer.clear_timeout`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-clear_timeout) or [`Workero.Timer.clear_interval`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-clear_interval) to stop a timer. Call timers from a handler or [`Workero.Context.wait_until`](https://ml-in-barcelona.github.io/workero/workero/Workero/Context/index.html#val-wait_until), not at startup. A timer callback cannot call [`Workero.Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await); use [`Workero.Timer.sleep`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-sleep) inside a handler when you need to wait.


## Time

[`Workero.Date.now`](https://ml-in-barcelona.github.io/workero/workero/Workero/Date/index.html#val-now) is `Date.now()`. [`Workero.Date.to_iso_string`](https://ml-in-barcelona.github.io/workero/workero/Workero/Date/index.html#val-to_iso_string) is `new Date(t).toISOString()`. Times are milliseconds since the Unix epoch, as a `float`. In Workers the clock moves only after I/O. It does not measure CPU time.


## Randomness

[`Workero.Crypto.random_uuid`](https://ml-in-barcelona.github.io/workero/workero/Workero/Crypto/index.html#val-random_uuid) returns a random version 4 UUID. [`Workero.Crypto.random_bytes`](https://ml-in-barcelona.github.io/workero/workero/Workero/Crypto/index.html#val-random_bytes) returns cryptographically random bytes. It accepts at most 65536 bytes per call and raises `Invalid_argument` for a negative size or a larger request. [`Workero.Crypto`](./Workero-Crypto.md) binds only these random functions, not the full Web Crypto API.

For logging, use [Console or standard output](./logging.md). For other globals, see [JavaScript interop](./interop.md) and [supported web standards](https://developers.cloudflare.com/workers/runtime-apis/web-standards/).
