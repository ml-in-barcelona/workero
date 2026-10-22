
# Module `Crypto.Key`

```ocaml
type 'kind t
```
A `CryptoKey`. The key is not extractable: its bytes cannot be read back. The type parameter names the algorithm, so an HMAC key cannot be given to an AES-GCM function.

```ocaml
type hmac
```
```ocaml
type aes_gcm
```
```ocaml
val import_hmac : hash -> string -> hmac t
```
`import_hmac hash raw` imports the raw bytes `raw` as an HMAC key for `hash`, with usages `sign` and `verify`.

Raises `Invalid_argument` when `raw` is empty.

```ocaml
val import_aes_gcm : string -> aes_gcm t
```
`import_aes_gcm raw` imports `raw` as an AES-GCM key, with usages `encrypt` and `decrypt`.

Raises `Invalid_argument` unless `raw` has 16, 24 or 32 bytes.
