
# Module `Crypto.Key`

```ocaml
type !'kind t
```
A `CryptoKey`. The type parameter names the algorithm, so an HMAC key cannot be given to an AES-GCM function. Keys from [`import_hmac`](./#val-import_hmac) and [`import_aes_gcm`](./#val-import_aes_gcm) are not extractable: their bytes cannot be read back. The other functions of this module take `?extractable`.

```ocaml
type hmac
```
```ocaml
type aes_gcm
```
```ocaml
type aes_cbc
```
```ocaml
type aes_ctr
```
```ocaml
type aes_kw
```
```ocaml
type rsassa_pkcs1_v1_5
```
```ocaml
type rsa_pss
```
```ocaml
type rsa_oaep
```
```ocaml
type ecdsa
```
```ocaml
type ecdh
```
```ocaml
type ed25519
```
```ocaml
type x25519
```
```ocaml
type !'algo public
```
The kind of the public half of an asymmetric key: `rsa_pss public t`.

```ocaml
type !'algo private_
```
The kind of the private half of an asymmetric key.

```ocaml
type 'algo pair = {
  public : 'algo public t;
  private_ : 'algo private_ t;
}
```
A `CryptoKeyPair`.


### Algorithms

```ocaml
type _ secret_algorithm = 
  | Hmac : hash -> hmac secret_algorithm
  | Aes_gcm : aes_gcm secret_algorithm
  | Aes_cbc : aes_cbc secret_algorithm
  | Aes_ctr : aes_ctr secret_algorithm
  | Aes_kw : aes_kw secret_algorithm (* A symmetric algorithm. Its index is the kind of the key. *)
```
```ocaml
type _ pair_algorithm = 
  | Rsassa_pkcs1_v1_5 : hash -> rsassa_pkcs1_v1_5 pair_algorithm
  | Rsa_pss : hash -> rsa_pss pair_algorithm
  | Rsa_oaep : hash -> rsa_oaep pair_algorithm
  | Ecdsa : curve -> ecdsa pair_algorithm
  | Ecdh : curve -> ecdh pair_algorithm
  | Ed25519 : ed25519 pair_algorithm
  | X25519 : x25519 pair_algorithm (* An asymmetric algorithm. The hash of an RSA algorithm belongs to the key, as in Web Crypto. ECDSA takes its hash when it signs. *)
```

### Generate

```ocaml
val generate : ?extractable:bool -> ?bits:int -> 'k secret_algorithm -> 'k t
```
`generate algorithm` makes a random key. `extractable` is `false` by default. `bits` is 128, 192 or 256 for AES, and 256 by default. For HMAC it is the key length, and by default the block size of the hash. The usages follow the algorithm: `sign` and `verify` for HMAC, `encrypt`, `decrypt`, `wrapKey` and `unwrapKey` for AES-GCM, AES-CBC and AES-CTR, and `wrapKey` and `unwrapKey` for AES-KW.

Raises `Invalid_argument` for other `bits`.

```ocaml
val generate_pair : 
  ?extractable:bool ->
  ?modulus_bits:int ->
  'a pair_algorithm ->
  'a pair
```
`generate_pair algorithm` makes a random key pair. The public key is always extractable, as Web Crypto says. `modulus_bits` is for RSA only: 2048 by default, and the public exponent is 65537\. The usages follow the algorithm: `verify` on the public and `sign` on the private key of RSASSA-PKCS1-v1\_5, RSA-PSS, ECDSA and Ed25519; `encrypt` and `wrapKey`, and `decrypt` and `unwrapKey`, for RSA-OAEP; `deriveBits` on the private key of ECDH and X25519.

Raises `Invalid_argument` when `modulus_bits` is under 512, or given for an algorithm that is not RSA.


### Import and export

```ocaml
type _ import = 
  | Secret_raw : 'k secret_algorithm -> 'k t import
  | Secret_jwk : 'k secret_algorithm -> 'k t import
  | Public_raw : 'a pair_algorithm -> 'a public t import
  | Public_spki : 'a pair_algorithm -> 'a public t import
  | Public_jwk : 'a pair_algorithm -> 'a public t import
  | Private_pkcs8 : 'a pair_algorithm -> 'a private_ t import
  | Private_jwk : 'a pair_algorithm -> 'a private_ t import (* What to import: a format and an algorithm. The index is the type of the key. raw, spki and pkcs8 data are bytes (DER for the last two). jwk data is the JSON text of a JSON Web Key. Public_raw is for ECDSA, ECDH, Ed25519 and X25519. *)
```
```ocaml
val import : ?extractable:bool -> 'k import -> string -> 'k
```
`import ?extractable what data` is `crypto.subtle.importKey`. The usages follow the algorithm, as in [`generate`](./#val-generate) and [`generate_pair`](./#val-generate_pair). `extractable` is `false` by default.

Raises `Invalid_argument` for `Public_raw` with an RSA algorithm. Data in the wrong format, or a key that does not fit the algorithm, raises [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error).

```ocaml
val export_raw : 'kind t -> string
```
The `raw` bytes of a secret key, or of the public key of ECDSA, ECDH, Ed25519 and X25519.

```ocaml
val export_jwk : 'kind t -> string
```
The JSON text of the JSON Web Key.

```ocaml
val export_spki : 'algo public t -> string
```
The DER `SubjectPublicKeyInfo` of a public key.

```ocaml
val export_pkcs8 : 'algo private_ t -> string
```
The DER `PrivateKeyInfo` of a private key.

The export functions raise [`Promise.Js_error`](./Workero-Promise.md#exception-Js_error) when the key is not extractable, or when the format does not exist for the algorithm, such as [`export_raw`](./#val-export_raw) for an RSA key or a private key.

```ocaml
val extractable : 'kind t -> bool
```

### Raw keys without options

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
