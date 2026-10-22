
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


### Subtle crypto

[`Workero.Crypto`](./Workero-Crypto.md) wraps a first subset of `crypto.subtle`. Data goes in and out as OCaml strings that hold raw bytes. The functions suspend the request while the runtime works, so call them inside a handler.

```ocaml
let sign_and_check secret body =
  let key = Crypto.Key.import_hmac Crypto.Sha256 secret in
  let signature = Crypto.hmac_sign key body in
  Crypto.hmac_verify key ~signature body
```
- [`Workero.Crypto.digest`](./Workero-Crypto.md#val-digest): SHA-1, SHA-256, SHA-384 and SHA-512, chosen by [`Workero.Crypto.hash`](./Workero-Crypto.md#type-hash).
- [`Workero.Crypto.Key.import_hmac`](./Workero-Crypto-Key.md#val-import_hmac), [`Workero.Crypto.hmac_sign`](./Workero-Crypto.md#val-hmac_sign) and [`Workero.Crypto.hmac_verify`](./Workero-Crypto.md#val-hmac_verify).
- [`Workero.Crypto.Key.import_aes_gcm`](./Workero-Crypto-Key.md#val-import_aes_gcm), [`Workero.Crypto.aes_gcm_encrypt`](./Workero-Crypto.md#val-aes_gcm_encrypt) and [`Workero.Crypto.aes_gcm_decrypt`](./Workero-Crypto.md#val-aes_gcm_decrypt). The cipher text ends with the 16-byte tag. Decryption gives `None` when authentication fails.
- [`Workero.Crypto.pbkdf2`](./Workero-Crypto.md#val-pbkdf2) and [`Workero.Crypto.hkdf`](./Workero-Crypto.md#val-hkdf) derive bytes.
A `Key.t` is a non-extractable `CryptoKey`. Its type names the algorithm, so the compiler rejects an HMAC key in an AES-GCM function. Bad arguments that the library can check raise `Invalid_argument`. A rejection from the runtime raises [`Workero.Js_error`](./Workero.md#exception-Js_error). Deployed Workers allow at most 100000 PBKDF2 iterations.


## Console

[`Workero.Console`](./Workero-Console.md) writes log entries. See [Logging](./logging.md).

For other globals, use raw interop. See [JavaScript interop](./interop.md).
