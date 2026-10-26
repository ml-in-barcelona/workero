(** The Web Crypto functions of the global [crypto] object: random values and
    [crypto.subtle]. See {{!page-globals}Timers, time, and randomness} and
    {{!page-crypto}Web Crypto}. *)

val random_uuid : unit -> string
(** [crypto.randomUUID()]: a random version 4 UUID, for example
    ["1b4e28ba-2fa1-41d2-883f-0016d3cca427"]. *)

val random_bytes : int -> string
(** [random_bytes n] is [n] cryptographically random bytes, from
    [crypto.getRandomValues].

    Raises [Invalid_argument] when [n] is negative or more than 65536, the limit
    of [getRandomValues]. *)

(** {1 Web Crypto [crypto.subtle]}

    [crypto.subtle]: digests, HMAC, AES (GCM, CBC, CTR, KW), RSA
    (RSASSA-PKCS1-v1_5, RSA-PSS, RSA-OAEP), ECDSA, ECDH, Ed25519, X25519, PBKDF2
    and HKDF. It has key generation, import and export in the formats [raw],
    [jwk], [spki] and [pkcs8], [wrapKey] and [unwrapKey], [deriveKey], and the
    Cloudflare extension [timingSafeEqual]. Data goes in and out as OCaml
    strings that hold raw bytes. The functions below suspend the request while
    the runtime works, like {!Promise.await}, so call them only inside a
    handler.

    The type of a key names its algorithm, and for an asymmetric key its half:
    {!Key.type-public} or {!Key.type-private_}. The compiler rejects an HMAC key
    in {!rsa_pss_verify}, and a public key in {!rsa_pss_sign}.

    A rejection from the runtime raises {!Promise.Js_error}. See
    {{!page-known_issues}Known issues} for what is missing. *)

type hash =
  | Sha1
  | Sha256
  | Sha384
  | Sha512
      (** A hash algorithm of [crypto.subtle]: [Sha1] for SHA-1, [Sha256] for
          SHA-256, [Sha384] for SHA-384 and [Sha512] for SHA-512. *)

val digest : hash -> string -> string
(** [digest hash data] is [crypto.subtle.digest]: the raw digest of [data].
    SHA-1 gives 20 bytes, SHA-256 32, SHA-384 48 and SHA-512 64. *)

type curve =
  | P256
  | P384
  | P521
      (** An elliptic curve of [crypto.subtle]: [P256] for P-256, [P384] for
          P-384 and [P521] for P-521. *)

module Key : sig
  type !'kind t
  (** A [CryptoKey]. The type parameter names the algorithm, so an HMAC key
      cannot be given to an AES-GCM function. Keys from {!import_hmac} and
      {!import_aes_gcm} are not extractable: their bytes cannot be read back.
      The other functions of this module take [?extractable]. *)

  type hmac
  type aes_gcm
  type aes_cbc
  type aes_ctr
  type aes_kw
  type rsassa_pkcs1_v1_5
  type rsa_pss
  type rsa_oaep
  type ecdsa
  type ecdh
  type ed25519
  type x25519

  type !'algo public
  (** The kind of the public half of an asymmetric key: [rsa_pss public t]. *)

  type !'algo private_
  (** The kind of the private half of an asymmetric key. *)

  type 'algo pair = { public : 'algo public t; private_ : 'algo private_ t }
  (** A [CryptoKeyPair]. *)

  (** {2 Algorithms} *)

  type _ secret_algorithm =
    | Hmac : hash -> hmac secret_algorithm
    | Aes_gcm : aes_gcm secret_algorithm
    | Aes_cbc : aes_cbc secret_algorithm
    | Aes_ctr : aes_ctr secret_algorithm
    | Aes_kw : aes_kw secret_algorithm
        (** A symmetric algorithm. Its index is the kind of the key. *)

  type _ pair_algorithm =
    | Rsassa_pkcs1_v1_5 : hash -> rsassa_pkcs1_v1_5 pair_algorithm
    | Rsa_pss : hash -> rsa_pss pair_algorithm
    | Rsa_oaep : hash -> rsa_oaep pair_algorithm
    | Ecdsa : curve -> ecdsa pair_algorithm
    | Ecdh : curve -> ecdh pair_algorithm
    | Ed25519 : ed25519 pair_algorithm
    | X25519 : x25519 pair_algorithm
        (** An asymmetric algorithm. The hash of an RSA algorithm belongs to the
            key, as in Web Crypto. ECDSA takes its hash when it signs. *)

  (** {2 Generate} *)

  val generate : ?extractable:bool -> ?bits:int -> 'k secret_algorithm -> 'k t
  (** [generate algorithm] makes a random key. [extractable] is [false] by
      default. [bits] is 128, 192 or 256 for AES, and 256 by default. For HMAC
      it is the key length, and by default the block size of the hash. The
      usages follow the algorithm: [sign] and [verify] for HMAC, [encrypt],
      [decrypt], [wrapKey] and [unwrapKey] for AES-GCM, AES-CBC and AES-CTR, and
      [wrapKey] and [unwrapKey] for AES-KW.

      Raises [Invalid_argument] for other [bits]. *)

  val generate_pair :
    ?extractable:bool ->
    ?modulus_bits:int ->
    ?public_exponent:int ->
    'a pair_algorithm ->
    'a pair
  (** [generate_pair algorithm] makes a random key pair. The public key is
      always extractable, as Web Crypto says. [modulus_bits] and
      [public_exponent] are for RSA only: 2048 and 65537 by default. [workerd]
      accepts 3 and 65537 as the exponent and rejects any other value, as a
      {!Promise.Js_error}. The usages follow the algorithm: [verify] on the
      public and [sign] on the private key of RSASSA-PKCS1-v1_5, RSA-PSS, ECDSA
      and Ed25519; [encrypt] and [wrapKey], and [decrypt] and [unwrapKey], for
      RSA-OAEP; [deriveBits] and [deriveKey] on the private key of ECDH and
      X25519.

      Raises [Invalid_argument] when [modulus_bits] is under 512, when
      [public_exponent] is not positive, or when either is given for an
      algorithm that is not RSA. *)

  (** {2 Import and export} *)

  type _ import =
    | Secret_raw : 'k secret_algorithm -> 'k t import
    | Secret_jwk : 'k secret_algorithm -> 'k t import
    | Public_raw : 'a pair_algorithm -> 'a public t import
    | Public_spki : 'a pair_algorithm -> 'a public t import
    | Public_jwk : 'a pair_algorithm -> 'a public t import
    | Private_pkcs8 : 'a pair_algorithm -> 'a private_ t import
    | Private_jwk : 'a pair_algorithm -> 'a private_ t import
        (** What to import: a format and an algorithm. The index is the type of
            the key. [raw], [spki] and [pkcs8] data are bytes (DER for the last
            two). [jwk] data is the JSON text of a JSON Web Key. [Public_raw] is
            for ECDSA, ECDH, Ed25519 and X25519. *)

  val import : ?extractable:bool -> 'k import -> string -> 'k
  (** [import ?extractable what data] is [crypto.subtle.importKey]. The usages
      follow the algorithm, as in {!val-generate} and {!val-generate_pair}.
      [extractable] is [false] by default.

      Raises [Invalid_argument] for [Public_raw] with an RSA algorithm. Data in
      the wrong format, or a key that does not fit the algorithm, raises
      {!Promise.Js_error}. *)

  val export_raw : 'kind t -> string
  (** The [raw] bytes of a secret key, or of the public key of ECDSA, ECDH,
      Ed25519 and X25519. *)

  val export_jwk : 'kind t -> string
  (** The JSON text of the JSON Web Key. *)

  val export_spki : 'algo public t -> string
  (** The DER [SubjectPublicKeyInfo] of a public key. *)

  val export_pkcs8 : 'algo private_ t -> string
  (** The DER [PrivateKeyInfo] of a private key. *)

  (** The export functions raise {!Promise.Js_error} when the key is not
      extractable, or when the format does not exist for the algorithm, such as
      {!export_raw} for an RSA key or a private key. *)

  val extractable : 'kind t -> bool

  val algorithm : 'kind t -> string
  (** The JSON text of the [algorithm] property of the key, for example
      [{"name":"AES-GCM","length":256}] or
      [{"name":"ECDSA","namedCurve":"P-256"}]. The hash of an HMAC or RSA key is
      an object, [{"name":"SHA-256"}]. *)

  val usages : 'kind t -> string list
  (** The [usages] property of the key, for example [["sign"; "verify"]]. The
      order is the one of the runtime. *)

  (** {2 Raw keys without options} *)

  val import_hmac : hash -> string -> hmac t
  (** [import_hmac hash raw] imports the raw bytes [raw] as an HMAC key for
      [hash], with usages [sign] and [verify].

      Raises [Invalid_argument] when [raw] is empty. *)

  val import_aes_gcm : string -> aes_gcm t
  (** [import_aes_gcm raw] imports [raw] as an AES-GCM key, with usages
      [encrypt] and [decrypt].

      Raises [Invalid_argument] unless [raw] has 16, 24 or 32 bytes. *)
end

val timing_safe_equal : string -> string -> bool
(** [timing_safe_equal a b] is [crypto.subtle.timingSafeEqual], a Cloudflare
    extension: [true] when [a] and [b] hold the same bytes. The comparison does
    not stop at the first difference, so its time does not tell an attacker
    where the strings differ. Strings of different lengths give [false] at once:
    the length is not secret. Use it to compare MACs, tokens and passwords. *)

val hmac_sign : Key.hmac Key.t -> string -> string
(** [hmac_sign key data] is the HMAC of [data]. Its length is the digest length
    of the hash given to {!Key.import_hmac}. *)

val hmac_verify : Key.hmac Key.t -> signature:string -> string -> bool
(** [hmac_verify key ~signature data] is [true] when [signature] is the HMAC of
    [data]. The runtime compares in constant time. *)

val aes_gcm_encrypt :
  Key.aes_gcm Key.t -> iv:string -> ?aad:string -> string -> string
(** [aes_gcm_encrypt key ~iv ?aad plain] encrypts [plain] with a 128-bit tag.
    The result is the cipher text followed by the 16-byte tag. [aad] is
    additional authenticated data. Never use the same [iv] twice with one key. A
    12-byte [iv] is the usual choice.

    Raises [Invalid_argument] when [iv] is empty. *)

val aes_gcm_decrypt :
  Key.aes_gcm Key.t -> iv:string -> ?aad:string -> string -> string option
(** [aes_gcm_decrypt key ~iv ?aad data] reverses {!aes_gcm_encrypt}. [data] is
    the cipher text followed by the tag. It is [None] when authentication fails:
    a wrong key, [iv] or [aad], or changed data.

    Raises [Invalid_argument] when [iv] is empty. *)

val pbkdf2 :
  hash ->
  password:string ->
  salt:string ->
  iterations:int ->
  length:int ->
  string
(** [pbkdf2 hash ~password ~salt ~iterations ~length] derives [length] bytes
    with PBKDF2. Deployed Cloudflare Workers reject more than 100000 iterations,
    as a {!Promise.Js_error}. Local [workerd] does not.

    Raises [Invalid_argument] when [iterations] or [length] is not positive. *)

val hkdf :
  hash -> key:string -> salt:string -> info:string -> length:int -> string
(** [hkdf hash ~key ~salt ~info ~length] derives [length] bytes with HKDF (RFC
    5869). [key] is the input key material.

    Raises [Invalid_argument] when [length] is not positive. A [length] over 255
    times the digest length is a {!Promise.Js_error}. *)

val pbkdf2_key :
  hash ->
  password:string ->
  salt:string ->
  iterations:int ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
(** [pbkdf2_key hash ~password ~salt ~iterations algorithm] is
    [crypto.subtle.deriveKey] with PBKDF2: it derives a key for [algorithm]
    without giving the bytes to OCaml. The key has the same bytes as the first
    bytes of {!pbkdf2}. [extractable] is [false] by default. [bits] is as in
    {!Key.val-generate}: 128, 192 or 256 for AES and 256 by default, and the key
    length for HMAC. The usages follow the algorithm, as in {!Key.val-generate}.
    The limit of 100000 iterations on deployed Workers applies.

    Raises [Invalid_argument] when [iterations] is not positive or [bits] is not
    valid for [algorithm]. *)

val hkdf_key :
  hash ->
  key:string ->
  salt:string ->
  info:string ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
(** Like {!pbkdf2_key} for HKDF (RFC 5869). [key] is the input key material.

    Raises [Invalid_argument] when [bits] is not valid for the algorithm. *)

(** {1 Signatures} *)

val rsassa_pkcs1_sign :
  Key.rsassa_pkcs1_v1_5 Key.private_ Key.t -> string -> string
(** [rsassa_pkcs1_sign key data] signs [data] with RSASSA-PKCS1-v1_5 and the
    hash of [key]. The signature is deterministic and as long as the modulus. *)

val rsassa_pkcs1_verify :
  Key.rsassa_pkcs1_v1_5 Key.public Key.t -> signature:string -> string -> bool
(** [rsassa_pkcs1_verify key ~signature data] is [true] when [signature] is
    valid for [data]. A wrong or malformed signature gives [false]. *)

val rsa_pss_sign :
  Key.rsa_pss Key.private_ Key.t -> salt_length:int -> string -> string
(** [rsa_pss_sign key ~salt_length data] signs [data] with RSA-PSS. A
    [salt_length] equal to the digest length is the usual choice.

    Raises [Invalid_argument] when [salt_length] is negative. *)

val rsa_pss_verify :
  Key.rsa_pss Key.public Key.t ->
  salt_length:int ->
  signature:string ->
  string ->
  bool
(** Like {!rsassa_pkcs1_verify} for RSA-PSS.

    Raises [Invalid_argument] when [salt_length] is negative. *)

val ecdsa_sign : hash -> Key.ecdsa Key.private_ Key.t -> string -> string
(** [ecdsa_sign hash key data] signs [data] with ECDSA. The signature is the
    fixed-size concatenation of [r] and [s] (IEEE P1363), not DER: 64 bytes for
    P-256, 96 for P-384 and 132 for P-521. It differs on every call. *)

val ecdsa_verify :
  hash -> Key.ecdsa Key.public Key.t -> signature:string -> string -> bool
(** Like {!rsassa_pkcs1_verify} for ECDSA. *)

val ed25519_sign : Key.ed25519 Key.private_ Key.t -> string -> string
(** [ed25519_sign key data] is the 64-byte Ed25519 signature of [data]. *)

val ed25519_verify :
  Key.ed25519 Key.public Key.t -> signature:string -> string -> bool
(** Like {!rsassa_pkcs1_verify} for Ed25519. A [signature] that is not 64 bytes
    gives [false]. *)

(** {1 Encryption} *)

val rsa_oaep_encrypt :
  Key.rsa_oaep Key.public Key.t -> ?label:string -> string -> string
(** [rsa_oaep_encrypt key ?label plain] encrypts [plain] with RSA-OAEP. The size
    of [plain] has a limit that depends on the modulus and the hash. Larger data
    raises {!Promise.Js_error}. *)

val rsa_oaep_decrypt :
  Key.rsa_oaep Key.private_ Key.t -> ?label:string -> string -> string option
(** [rsa_oaep_decrypt key ?label data] reverses {!rsa_oaep_encrypt}. It is
    [None] for a wrong key or [label], or changed data. *)

val aes_cbc_encrypt : Key.aes_cbc Key.t -> iv:string -> string -> string
(** [aes_cbc_encrypt key ~iv plain] encrypts [plain] with PKCS#7 padding. The
    result is a multiple of 16 bytes and longer than [plain]. Use a random [iv],
    and never an [iv] that an attacker can predict. AES-CBC has no
    authentication; prefer {!aes_gcm_encrypt}.

    Raises [Invalid_argument] unless [iv] has 16 bytes. *)

val aes_cbc_decrypt : Key.aes_cbc Key.t -> iv:string -> string -> string option
(** [aes_cbc_decrypt key ~iv data] reverses {!aes_cbc_encrypt}. It is [None]
    when the padding is wrong, which usually means a wrong key or [iv]. It can
    also give wrong bytes without an error.

    Raises [Invalid_argument] unless [iv] has 16 bytes. *)

val aes_ctr_encrypt :
  Key.aes_ctr Key.t -> counter:string -> counter_bits:int -> string -> string
(** [aes_ctr_encrypt key ~counter ~counter_bits plain] encrypts [plain] in
    counter mode. [counter] is the 16-byte initial counter block. [counter_bits]
    is how many low bits of it count; the rest is a fixed nonce. The result has
    the length of [plain]. AES-CTR has no authentication. Never reuse a counter
    block with one key.

    Raises [Invalid_argument] unless [counter] has 16 bytes and [counter_bits]
    is from 1 to 128. *)

val aes_ctr_decrypt :
  Key.aes_ctr Key.t -> counter:string -> counter_bits:int -> string -> string
(** The same as {!aes_ctr_encrypt}: counter mode decrypts by encrypting again.
    Wrong data gives wrong bytes, not an error. *)

(** {1 Key agreement} *)

val ecdh_derive_bits :
  Key.ecdh Key.private_ Key.t ->
  public:Key.ecdh Key.public Key.t ->
  length:int ->
  string
(** [ecdh_derive_bits key ~public ~length] is the first [length] bytes of the
    ECDH shared secret between [key] and [public]. Both parties get the same
    bytes. The raw secret is not uniform: run it through {!hkdf}.

    Raises [Invalid_argument] when [length] is not positive. A [length] over the
    size of the curve is a {!Promise.Js_error}. *)

val x25519_derive_bits :
  Key.x25519 Key.private_ Key.t ->
  public:Key.x25519 Key.public Key.t ->
  length:int ->
  string
(** Like {!ecdh_derive_bits} for X25519. The secret has 32 bytes. *)

val ecdh_derive_key :
  Key.ecdh Key.private_ Key.t ->
  public:Key.ecdh Key.public Key.t ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
(** [ecdh_derive_key key ~public algorithm] is [crypto.subtle.deriveKey] with
    ECDH: a key for [algorithm] made from the shared secret of [key] and
    [public]. Both parties get the same key. [extractable] and [bits] are as in
    {!pbkdf2_key}. The private key needs the [deriveKey] usage, which keys from
    {!Key.val-generate_pair} and {!Key.val-import} have.

    Raises [Invalid_argument] when [bits] is not valid for [algorithm]. *)

val x25519_derive_key :
  Key.x25519 Key.private_ Key.t ->
  public:Key.x25519 Key.public Key.t ->
  ?extractable:bool ->
  ?bits:int ->
  'k Key.secret_algorithm ->
  'k Key.t
(** Like {!ecdh_derive_key} for X25519. *)

(** {1 Wrapping keys} *)

type format =
  | Raw
  | Jwk
  | Pkcs8
  | Spki  (** The format of an exported key, for {!wrap_key}. *)

type wrapping
type unwrapping

type _ wrapper =
  | Aes_kw : Key.aes_kw Key.t -> 'role wrapper
  | Aes_gcm : {
      key : Key.aes_gcm Key.t;
      iv : string;
      aad : string option;
    }
      -> 'role wrapper
  | Aes_cbc : { key : Key.aes_cbc Key.t; iv : string } -> 'role wrapper
  | Aes_ctr : {
      key : Key.aes_ctr Key.t;
      counter : string;
      counter_bits : int;
    }
      -> 'role wrapper
  | Rsa_oaep_wrap : {
      key : Key.rsa_oaep Key.public Key.t;
      label : string option;
    }
      -> wrapping wrapper
  | Rsa_oaep_unwrap : {
      key : Key.rsa_oaep Key.private_ Key.t;
      label : string option;
    }
      -> unwrapping wrapper
      (** A key that wraps other keys, with the algorithm parameters. The index
          tells the direction: RSA-OAEP wraps with the public key and unwraps
          with the private key. [Aes_cbc] and [Aes_ctr] take the parameters of
          {!aes_cbc_encrypt} and {!aes_ctr_encrypt}; they do not authenticate
          the wrapped key, so prefer [Aes_kw] or [Aes_gcm]. A key from
          {!Key.import_aes_gcm} cannot wrap; use {!Key.val-generate} or
          {!Key.val-import}. *)

val wrap_key : wrapping wrapper -> format:format -> 'kind Key.t -> string
(** [wrap_key wrapper ~format key] is [crypto.subtle.wrapKey]: the key [key],
    exported in [format] and encrypted. [key] must be extractable. The wrapping
    key needs the [wrapKey] usage.

    Raises [Invalid_argument] when [Aes_gcm] has an empty [iv], when [Aes_cbc]
    has an [iv] that is not 16 bytes, or when [Aes_ctr] has a bad [counter] or
    [counter_bits]. Other failures, such as a non-extractable [key] or an unfit
    [format], raise {!Promise.Js_error}. *)

val unwrap_key :
  ?extractable:bool -> unwrapping wrapper -> 'k Key.import -> string -> 'k
(** [unwrap_key wrapper what wrapped] is [crypto.subtle.unwrapKey]: it decrypts
    [wrapped] and imports the result as [what] says. A wrong key or changed data
    raises {!Promise.Js_error}.

    Raises [Invalid_argument] for the same wrapper arguments as {!wrap_key}. *)

(** {1 Streaming digests} *)

module Digest_stream : sig
  type t
  (** The runtime [DigestStream]: a writable stream that hashes what you write
      to it, without keeping the data. *)

  val create : hash -> t

  val writer : t -> Stream.Writer.t
  (** Locks the stream. Write the data, then {!Stream.Writer.close}. *)

  val digest : t -> string
  (** The raw digest. Suspends until the writer is closed. *)
end
