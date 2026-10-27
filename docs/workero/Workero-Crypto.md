
# Module `Workero.Crypto`

The Web Crypto functions of the global `crypto` object: random values and `crypto.subtle`. See [Timers, time, and randomness](./globals.md) and [Web Crypto](./crypto.md).

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

`crypto.subtle`: digests, HMAC, AES (GCM, CBC, CTR, KW), RSA (RSASSA-PKCS1-v1\_5, RSA-PSS, RSA-OAEP), ECDSA, ECDH, Ed25519, X25519, PBKDF2 and HKDF. It has key generation, import and export in the formats `raw`, `jwk`, `spki` and `pkcs8`, `wrapKey` and `unwrapKey`, `deriveKey`, and the Cloudflare extension `timingSafeEqual`. Data goes in and out as OCaml strings that hold raw bytes. The functions below suspend the request while the runtime works, like [`Promise.await`](./Workero-Promise.md#val-await), so call them only inside a handler.

The type of a key names its algorithm, and for an asymmetric key its half: [`Key.public`](./Workero-Crypto-Key.md#type-public) or [`Key.private_`](./Workero-Crypto-Key.md#type-private_). The compiler rejects an HMAC key in [`rsa_pss_verify`](./#val-rsa_pss_verify), and a public key in [`rsa_pss_sign`](./#val-rsa_pss_sign).

A rejection from the runtime raises [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error). See the [open issues](https://github.com/ml-in-barcelona/workero/issues) for what is missing.

```ocaml
type hash = 
  | Sha1
  | Sha256
  | Sha384
  | Sha512 (* A hash algorithm of crypto.subtle: Sha1 for SHA-1, Sha256 for SHA-256, Sha384 for SHA-384 and Sha512 for SHA-512. *)
```
```ocaml
val digest : hash -> string -> string
```
`digest hash data` is `crypto.subtle.digest`: the raw digest of `data`. SHA-1 gives 20 bytes, SHA-256 32, SHA-384 48 and SHA-512 64\.

```ocaml
type curve = 
  | P256
  | P384
  | P521 (* An elliptic curve of crypto.subtle: P256 for P-256, P384 for P-384 and P521 for P-521. *)
```
```ocaml
module Key : sig ... end
```
```ocaml
val timing_safe_equal : string -> string -> bool
```
`timing_safe_equal a b` is `crypto.subtle.timingSafeEqual`, a Cloudflare extension: `true` when `a` and `b` hold the same bytes. The comparison does not stop at the first difference, so its time does not tell an attacker where the strings differ. Strings of different lengths give `false` at once: the length is not secret. Use it to compare MACs, tokens and passwords.

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

```ocaml
val pbkdf2_key : 
  hash ->
  password:string ->
  salt:string ->
  iterations:int ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
```
`pbkdf2_key hash ~password ~salt ~iterations algorithm` is `crypto.subtle.deriveKey` with PBKDF2: it derives a key for `algorithm` without giving the bytes to OCaml. The key has the same bytes as the first bytes of [`pbkdf2`](./#val-pbkdf2). `extractable` is `false` by default. `bits` is as in [`Key.generate`](./Workero-Crypto-Key.md#val-generate): 128, 192 or 256 for AES and 256 by default, and the key length for HMAC. The usages follow the algorithm, as in [`Key.generate`](./Workero-Crypto-Key.md#val-generate). The limit of 100000 iterations on deployed Workers applies.

Raises `Invalid_argument` when `iterations` is not positive or `bits` is not valid for `algorithm`.

```ocaml
val hkdf_key : 
  hash ->
  key:string ->
  salt:string ->
  info:string ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
```
Like [`pbkdf2_key`](./#val-pbkdf2_key) for HKDF (RFC 5869\). `key` is the input key material.

Raises `Invalid_argument` when `bits` is not valid for the algorithm.


## Signatures

```ocaml
val rsassa_pkcs1_sign : 
  Key.rsassa_pkcs1_v1_5 Key.private_ Key.t ->
  string ->
  string
```
`rsassa_pkcs1_sign key data` signs `data` with RSASSA-PKCS1-v1\_5 and the hash of `key`. The signature is deterministic and as long as the modulus.

```ocaml
val rsassa_pkcs1_verify : 
  Key.rsassa_pkcs1_v1_5 Key.public Key.t ->
  signature:string ->
  string ->
  bool
```
`rsassa_pkcs1_verify key ~signature data` is `true` when `signature` is valid for `data`. A wrong or malformed signature gives `false`.

```ocaml
val rsa_pss_sign : 
  Key.rsa_pss Key.private_ Key.t ->
  salt_length:int ->
  string ->
  string
```
`rsa_pss_sign key ~salt_length data` signs `data` with RSA-PSS. A `salt_length` equal to the digest length is the usual choice.

Raises `Invalid_argument` when `salt_length` is negative.

```ocaml
val rsa_pss_verify : 
  Key.rsa_pss Key.public Key.t ->
  salt_length:int ->
  signature:string ->
  string ->
  bool
```
Like [`rsassa_pkcs1_verify`](./#val-rsassa_pkcs1_verify) for RSA-PSS.

Raises `Invalid_argument` when `salt_length` is negative.

```ocaml
val ecdsa_sign : hash -> Key.ecdsa Key.private_ Key.t -> string -> string
```
`ecdsa_sign hash key data` signs `data` with ECDSA. The signature is the fixed-size concatenation of `r` and `s` (IEEE P1363), not DER: 64 bytes for P-256, 96 for P-384 and 132 for P-521. It differs on every call.

```ocaml
val ecdsa_verify : 
  hash ->
  Key.ecdsa Key.public Key.t ->
  signature:string ->
  string ->
  bool
```
Like [`rsassa_pkcs1_verify`](./#val-rsassa_pkcs1_verify) for ECDSA.

```ocaml
val ed25519_sign : Key.ed25519 Key.private_ Key.t -> string -> string
```
`ed25519_sign key data` is the 64-byte Ed25519 signature of `data`.

```ocaml
val ed25519_verify : 
  Key.ed25519 Key.public Key.t ->
  signature:string ->
  string ->
  bool
```
Like [`rsassa_pkcs1_verify`](./#val-rsassa_pkcs1_verify) for Ed25519. A `signature` that is not 64 bytes gives `false`.


## Encryption

```ocaml
val rsa_oaep_encrypt : 
  Key.rsa_oaep Key.public Key.t ->
  ?label:string ->
  string ->
  string
```
`rsa_oaep_encrypt key ?label plain` encrypts `plain` with RSA-OAEP. The size of `plain` has a limit that depends on the modulus and the hash. Larger data raises [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error).

```ocaml
val rsa_oaep_decrypt : 
  Key.rsa_oaep Key.private_ Key.t ->
  ?label:string ->
  string ->
  string option
```
`rsa_oaep_decrypt key ?label data` reverses [`rsa_oaep_encrypt`](./#val-rsa_oaep_encrypt). It is `None` for a wrong key or `label`, or changed data.

```ocaml
val aes_cbc_encrypt : Key.aes_cbc Key.t -> iv:string -> string -> string
```
`aes_cbc_encrypt key ~iv plain` encrypts `plain` with PKCS\#7 padding. The result is a multiple of 16 bytes and longer than `plain`. Use a random `iv`, and never an `iv` that an attacker can predict. AES-CBC has no authentication; prefer [`aes_gcm_encrypt`](./#val-aes_gcm_encrypt).

Raises `Invalid_argument` unless `iv` has 16 bytes.

```ocaml
val aes_cbc_decrypt : Key.aes_cbc Key.t -> iv:string -> string -> string option
```
`aes_cbc_decrypt key ~iv data` reverses [`aes_cbc_encrypt`](./#val-aes_cbc_encrypt). It is `None` when the padding is wrong, which usually means a wrong key or `iv`. It can also give wrong bytes without an error.

Raises `Invalid_argument` unless `iv` has 16 bytes.

```ocaml
val aes_ctr_encrypt : 
  Key.aes_ctr Key.t ->
  counter:string ->
  counter_bits:int ->
  string ->
  string
```
`aes_ctr_encrypt key ~counter ~counter_bits plain` encrypts `plain` in counter mode. `counter` is the 16-byte initial counter block. `counter_bits` is how many low bits of it count; the rest is a fixed nonce. The result has the length of `plain`. AES-CTR has no authentication. Never reuse a counter block with one key.

Raises `Invalid_argument` unless `counter` has 16 bytes and `counter_bits` is from 1 to 128\.

```ocaml
val aes_ctr_decrypt : 
  Key.aes_ctr Key.t ->
  counter:string ->
  counter_bits:int ->
  string ->
  string
```
The same as [`aes_ctr_encrypt`](./#val-aes_ctr_encrypt): counter mode decrypts by encrypting again. Wrong data gives wrong bytes, not an error.


## Key agreement

```ocaml
val ecdh_derive_bits : 
  Key.ecdh Key.private_ Key.t ->
  public:Key.ecdh Key.public Key.t ->
  length:int ->
  string
```
`ecdh_derive_bits key ~public ~length` is the first `length` bytes of the ECDH shared secret between `key` and `public`. Both parties get the same bytes. The raw secret is not uniform: run it through [`hkdf`](./#val-hkdf).

Raises `Invalid_argument` when `length` is not positive. A `length` over the size of the curve is a [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error).

```ocaml
val x25519_derive_bits : 
  Key.x25519 Key.private_ Key.t ->
  public:Key.x25519 Key.public Key.t ->
  length:int ->
  string
```
Like [`ecdh_derive_bits`](./#val-ecdh_derive_bits) for X25519. The secret has 32 bytes.

```ocaml
val ecdh_derive_key : 
  Key.ecdh Key.private_ Key.t ->
  public:Key.ecdh Key.public Key.t ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
```
`ecdh_derive_key key ~public algorithm` is `crypto.subtle.deriveKey` with ECDH: a key for `algorithm` made from the shared secret of `key` and `public`. Both parties get the same key. `extractable` and `bits` are as in [`pbkdf2_key`](./#val-pbkdf2_key). The private key needs the `deriveKey` usage, which keys from [`Key.generate_pair`](./Workero-Crypto-Key.md#val-generate_pair) and [`Key.import`](./Workero-Crypto-Key.md#val-import) have.

Raises `Invalid_argument` when `bits` is not valid for `algorithm`.

```ocaml
val x25519_derive_key : 
  Key.x25519 Key.private_ Key.t ->
  public:Key.x25519 Key.public Key.t ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
```
Like [`ecdh_derive_key`](./#val-ecdh_derive_key) for X25519.


## Wrapping keys

```ocaml
type format = 
  | Raw
  | Jwk
  | Pkcs8
  | Spki (* The format of an exported key, for wrap_key. *)
```
```ocaml
type wrapping
```
```ocaml
type unwrapping
```
```ocaml
type _ wrapper = 
  | Aes_kw : Key.aes_kw Key.t -> 'role wrapper
  | Aes_gcm : {
    key : Key.aes_gcm Key.t;
    iv : string;
    aad : string option;
  } -> 'role wrapper
  | Aes_cbc : {
    key : Key.aes_cbc Key.t;
    iv : string;
  } -> 'role wrapper
  | Aes_ctr : {
    key : Key.aes_ctr Key.t;
    counter : string;
    counter_bits : int;
  } -> 'role wrapper
  | Rsa_oaep_wrap : {
    key : Key.rsa_oaep Key.public Key.t;
    label : string option;
  } -> wrapping wrapper
  | Rsa_oaep_unwrap : {
    key : Key.rsa_oaep Key.private_ Key.t;
    label : string option;
  } -> unwrapping wrapper (* A key that wraps other keys, with the algorithm parameters. The index tells the direction: RSA-OAEP wraps with the public key and unwraps with the private key. Aes_cbc and Aes_ctr take the parameters of aes_cbc_encrypt and aes_ctr_encrypt; they do not authenticate the wrapped key, so prefer Aes_kw or Aes_gcm. A key from Key.import_aes_gcm cannot wrap; use Key.generate or Key.import. *)
```
```ocaml
val wrap_key : wrapping wrapper -> format:format -> 'kind Key.t -> string
```
`wrap_key wrapper ~format key` is `crypto.subtle.wrapKey`: the key `key`, exported in `format` and encrypted. `key` must be extractable. The wrapping key needs the `wrapKey` usage.

Raises `Invalid_argument` when `Aes_gcm` has an empty `iv`, when `Aes_cbc` has an `iv` that is not 16 bytes, or when `Aes_ctr` has a bad `counter` or `counter_bits`. Other failures, such as a non-extractable `key` or an unfit `format`, raise [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error).

```ocaml
val unwrap_key : 
  ?extractable:bool ->
  unwrapping wrapper ->
  'k Key.import ->
  string ->
  'k
```
`unwrap_key wrapper what wrapped` is `crypto.subtle.unwrapKey`: it decrypts `wrapped` and imports the result as `what` says. A wrong key or changed data raises [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error).

Raises `Invalid_argument` for the same wrapper arguments as [`wrap_key`](./#val-wrap_key).


## Streaming digests

```ocaml
module Digest_stream : sig ... end
```