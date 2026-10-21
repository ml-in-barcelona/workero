
# JavaScript globals

Workero has typed bindings for four JavaScript globals. You do not need `Js_of_ocaml` to use them.


## Timer

[`Workero.Timer`](./Workero-Timer.md) wraps `setTimeout` and `setInterval`. Delays are in milliseconds.

```ocaml
let handler _req _env _ctx =
  let open Workero in
  Promise.await (Timer.sleep 100);
  let ticks = ref 0 in
  let interval = Timer.set_interval (fun () -> incr ticks) 20 in
  Promise.await (Timer.sleep 110);
  Timer.clear_interval interval;
  Response.text (Printf.sprintf "ticks: %d\n" !ticks)

let () = Workero.serve handler
```
Call timers only from a handler or from [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until). The Workers runtime refuses timers at startup. A callback runs outside the handler, so it cannot call [`Workero.Promise.await`](./Workero-Promise.md#val-await).


## Date

[`Workero.Date.now`](./Workero-Date.md#val-now) is `Date.now()`. [`Workero.Date.to_iso_string`](./Workero-Date.md#val-to_iso_string) is `new Date(t).toISOString()`. Times are milliseconds since the Unix epoch, as a `float`. In Workers the clock moves only after I/O. It does not measure CPU time.


## Crypto

[`Workero.Crypto.random_uuid`](./Workero-Crypto.md#val-random_uuid) returns a random version 4 UUID. [`Workero.Crypto.random_bytes`](./Workero-Crypto.md#val-random_bytes) returns cryptographically random bytes. It accepts at most 65536 bytes per call.


## Console

[`Workero.Console`](./Workero-Console.md) writes log entries. See [Logging](./logging.md).

For other globals, use raw interop. See [JavaScript interop](./interop.md).
