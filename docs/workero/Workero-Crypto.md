
# Module `Workero.Crypto`

The Web Crypto random functions of the global `crypto` object.

```ocaml
val random_uuid : unit -> string
```
`crypto.randomUUID()`: a random version 4 UUID, for example `"1b4e28ba-2fa1-41d2-883f-0016d3cca427"`.

```ocaml
val random_bytes : int -> string
```
`random_bytes n` is `n` cryptographically random bytes, from `crypto.getRandomValues`.

Raises `Invalid_argument` when `n` is negative or more than 65536, the limit of `getRandomValues`.


## Web Crypto `crypto.subtle`

A first subset of `crypto.subtle`: digests, HMAC, AES-GCM, PBKDF2 and HKDF. Data goes in and out as OCaml strings that hold raw bytes. The functions below suspend the request while the runtime works, like [`Promise.await`](./Workero-Promise.md#val-await), so call them only inside a handler.

A rejection from the runtime raises [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error). Other algorithms, key formats and key generation are not supported yet, see [Known issues](./known_issues.md).

```ocaml
type hash = 
  | Sha1
  | Sha256
  | Sha384
  | Sha512 (* A hash algorithm of crypto.subtle. *)
```
```ocaml
val digest : hash -> string -> string
```
`digest hash data` is `crypto.subtle.digest`: the raw digest of `data`. SHA-1 gives 20 bytes, SHA-256 32, SHA-384 48 and SHA-512 64\.

```ocaml
module Key : sig ... end
```
```ocaml
val hmac_sign : Key.hmac Key.t -> string -> string
```
`hmac_sign key data` is the HMAC of `data`. Its length is the digest length of the hash given to [`Key.import_hmac`](./Workero-Crypto-Key.md#val-import_hmac).

```ocaml
val hmac_verify : Key.hmac Key.t -> signature:string -> string -> bool
```
`hmac_verify key ~signature data` is `true` when `signature` is the HMAC of `data`. The runtime compares in constant time.

```ocaml
val aes_gcm_encrypt : 
  Key.aes_gcm Key.t ->
  iv:string ->
  ?aad:string ->
  string ->
  string
```
`aes_gcm_encrypt key ~iv ?aad plain` encrypts `plain` with a 128-bit tag. The result is the cipher text followed by the 16-byte tag. `aad` is additional authenticated data. Never use the same `iv` twice with one key. A 12-byte `iv` is the usual choice.

Raises `Invalid_argument` when `iv` is empty.

```ocaml
val aes_gcm_decrypt : 
  Key.aes_gcm Key.t ->
  iv:string ->
  ?aad:string ->
  string ->
  string option
```
`aes_gcm_decrypt key ~iv ?aad data` reverses [`aes_gcm_encrypt`](./#val-aes_gcm_encrypt). `data` is the cipher text followed by the tag. It is `None` when authentication fails: a wrong key, `iv` or `aad`, or changed data.

Raises `Invalid_argument` when `iv` is empty.

```ocaml
val pbkdf2 : 
  hash ->
  password:string ->
  salt:string ->
  iterations:int ->
  length:int ->
  string
```
`pbkdf2 hash ~password ~salt ~iterations ~length` derives `length` bytes with PBKDF2. Deployed Cloudflare Workers reject more than 100000 iterations, as a [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error). Local `workerd` does not.

Raises `Invalid_argument` when `iterations` or `length` is not positive.

```ocaml
val hkdf : 
  hash ->
  key:string ->
  salt:string ->
  info:string ->
  length:int ->
  string
```
`hkdf hash ~key ~salt ~info ~length` derives `length` bytes with HKDF (RFC 5869\). `key` is the input key material.

Raises `Invalid_argument` when `length` is not positive. A `length` over 255 times the digest length is a [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error).
