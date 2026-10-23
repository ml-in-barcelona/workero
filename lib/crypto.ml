module Js = Js_of_ocaml.Js

let crypto () = Internal.global "crypto"

let random_uuid () =
  Internal.Js.to_string
    (Internal.Js.Unsafe.coerce (Internal.meth (crypto ()) "randomUUID" [||]))

let max_bytes = 65536

let random_bytes n =
  if n < 0 || n > max_bytes then
    invalid_arg (Printf.sprintf "Workero.Crypto.random_bytes: %d" n);
  let buf =
    Internal.Js.Unsafe.new_obj
      (Internal.global "Uint8Array")
      [| Internal.Js.Unsafe.inject (Internal.Js.float (float_of_int n)) |]
  in
  ignore (Internal.meth (crypto ()) "getRandomValues" [| buf |]);
  String.init n (fun i ->
      Char.chr (Internal.int_of_js (Internal.Js.Unsafe.get buf i)))

type hash = Sha1 | Sha256 | Sha384 | Sha512

let hash_name = function
  | Sha1 -> "SHA-1"
  | Sha256 -> "SHA-256"
  | Sha384 -> "SHA-384"
  | Sha512 -> "SHA-512"

type curve = P256 | P384 | P521

let curve_name = function P256 -> "P-256" | P384 -> "P-384" | P521 -> "P-521"
let subtle () = Js.Unsafe.get (crypto ()) "subtle"
let js_str = Internal.str
let obj fields = Binding.options fields
let bytes = Wire.body_of_string
let subtle_call ~decode name args = Binding.call ~decode (subtle ()) name args

let digest hash data =
  subtle_call ~decode:Decode.bytes "digest"
    [| js_str (hash_name hash); bytes data |]

let js_bool b = Js.Unsafe.inject (Js.bool b)
let js_int n = Js.Unsafe.inject (Js.float (float_of_int n))

let json_parse text =
  Binding.invoke (Internal.global "JSON") "parse" [| js_str text |]

let json_stringify value =
  Internal.Js.to_string
    (Internal.Js.Unsafe.coerce
       (Binding.invoke (Internal.global "JSON") "stringify" [| value |]))

module Key = struct
  type 'kind t = { js : Internal.js } [@@unboxed]
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
  type 'algo public = |
  type 'algo private_ = |
  type 'algo pair = { public : 'algo public t; private_ : 'algo private_ t }

  type _ secret_algorithm =
    | Hmac : hash -> hmac secret_algorithm
    | Aes_gcm : aes_gcm secret_algorithm
    | Aes_cbc : aes_cbc secret_algorithm
    | Aes_ctr : aes_ctr secret_algorithm
    | Aes_kw : aes_kw secret_algorithm

  type _ pair_algorithm =
    | Rsassa_pkcs1_v1_5 : hash -> rsassa_pkcs1_v1_5 pair_algorithm
    | Rsa_pss : hash -> rsa_pss pair_algorithm
    | Rsa_oaep : hash -> rsa_oaep pair_algorithm
    | Ecdsa : curve -> ecdsa pair_algorithm
    | Ecdh : curve -> ecdh pair_algorithm
    | Ed25519 : ed25519 pair_algorithm
    | X25519 : x25519 pair_algorithm

  type _ import =
    | Secret_raw : 'k secret_algorithm -> 'k t import
    | Secret_jwk : 'k secret_algorithm -> 'k t import
    | Public_raw : 'a pair_algorithm -> 'a public t import
    | Public_spki : 'a pair_algorithm -> 'a public t import
    | Public_jwk : 'a pair_algorithm -> 'a public t import
    | Private_pkcs8 : 'a pair_algorithm -> 'a private_ t import
    | Private_jwk : 'a pair_algorithm -> 'a private_ t import

  let usages l =
    Js.Unsafe.inject (Js.array (Array.of_list (List.map Js.string l)))

  let secret_name : type k. k secret_algorithm -> string = function
    | Hmac _ -> "HMAC"
    | Aes_gcm -> "AES-GCM"
    | Aes_cbc -> "AES-CBC"
    | Aes_ctr -> "AES-CTR"
    | Aes_kw -> "AES-KW"

  let secret_usages : type k. k secret_algorithm -> string list = function
    | Hmac _ -> [ "sign"; "verify" ]
    | Aes_gcm | Aes_cbc | Aes_ctr ->
        [ "encrypt"; "decrypt"; "wrapKey"; "unwrapKey" ]
    | Aes_kw -> [ "wrapKey"; "unwrapKey" ]

  let secret_params : type k. k secret_algorithm -> (string * Internal.js) list
      = function
    | Hmac hash as a ->
        [ ("name", js_str (secret_name a)); ("hash", js_str (hash_name hash)) ]
    | a -> [ ("name", js_str (secret_name a)) ]

  let pair_name : type a. a pair_algorithm -> string = function
    | Rsassa_pkcs1_v1_5 _ -> "RSASSA-PKCS1-v1_5"
    | Rsa_pss _ -> "RSA-PSS"
    | Rsa_oaep _ -> "RSA-OAEP"
    | Ecdsa _ -> "ECDSA"
    | Ecdh _ -> "ECDH"
    | Ed25519 -> "Ed25519"
    | X25519 -> "X25519"

  let pair_params : type a. a pair_algorithm -> (string * Internal.js) list =
   fun a ->
    let name = ("name", js_str (pair_name a)) in
    match a with
    | Rsassa_pkcs1_v1_5 hash | Rsa_pss hash | Rsa_oaep hash ->
        [ name; ("hash", js_str (hash_name hash)) ]
    | Ecdsa curve | Ecdh curve ->
        [ name; ("namedCurve", js_str (curve_name curve)) ]
    | Ed25519 | X25519 -> [ name ]

  let is_rsa : type a. a pair_algorithm -> bool = function
    | Rsassa_pkcs1_v1_5 _ | Rsa_pss _ | Rsa_oaep _ -> true
    | Ecdsa _ | Ecdh _ | Ed25519 | X25519 -> false

  let public_usages : type a. a pair_algorithm -> string list = function
    | Rsassa_pkcs1_v1_5 _ | Rsa_pss _ | Ecdsa _ | Ed25519 -> [ "verify" ]
    | Rsa_oaep _ -> [ "encrypt"; "wrapKey" ]
    | Ecdh _ | X25519 -> []

  let private_usages : type a. a pair_algorithm -> string list = function
    | Rsassa_pkcs1_v1_5 _ | Rsa_pss _ | Ecdsa _ | Ed25519 -> [ "sign" ]
    | Rsa_oaep _ -> [ "decrypt"; "unwrapKey" ]
    | Ecdh _ | X25519 -> [ "deriveBits" ]

  let wrap js = { js }

  let import_raw ~extractable ~algorithm ~usages:u raw =
    wrap
      (subtle_call ~decode:Decode.js "importKey"
         [| js_str "raw"; bytes raw; algorithm; js_bool extractable; usages u |])

  let import_hmac hash raw =
    if raw = "" then invalid_arg "Workero.Crypto.Key.import_hmac: empty key";
    import_raw ~extractable:false
      ~algorithm:
        (obj [ ("name", js_str "HMAC"); ("hash", js_str (hash_name hash)) ])
      ~usages:[ "sign"; "verify" ] raw

  let import_aes_gcm raw =
    (match String.length raw with
    | 16 | 24 | 32 -> ()
    | n ->
        invalid_arg
          (Printf.sprintf
             "Workero.Crypto.Key.import_aes_gcm: %d bytes, expected 16, 24 or \
              32"
             n));
    import_raw ~extractable:false
      ~algorithm:(obj [ ("name", js_str "AES-GCM") ])
      ~usages:[ "encrypt"; "decrypt" ] raw

  let import_target : type r. r import -> string * Internal.js * string list =
    function
    | Secret_raw a -> ("raw", obj (secret_params a), secret_usages a)
    | Secret_jwk a -> ("jwk", obj (secret_params a), secret_usages a)
    | Public_raw a ->
        if is_rsa a then
          invalid_arg
            "Workero.Crypto.Key.import: raw is not an RSA public format";
        ("raw", obj (pair_params a), public_usages a)
    | Public_spki a -> ("spki", obj (pair_params a), public_usages a)
    | Public_jwk a -> ("jwk", obj (pair_params a), public_usages a)
    | Private_pkcs8 a -> ("pkcs8", obj (pair_params a), private_usages a)
    | Private_jwk a -> ("jwk", obj (pair_params a), private_usages a)

  let key_data format data =
    if format = "jwk" then json_parse data else bytes data

  let import (type r) ?(extractable = false) (spec : r import) data : r =
    let format, algorithm, u = import_target spec in
    let imported =
      subtle_call ~decode:Decode.js "importKey"
        [|
          js_str format;
          key_data format data;
          algorithm;
          js_bool extractable;
          usages u;
        |]
    in
    match spec with
    | Secret_raw _ -> wrap imported
    | Secret_jwk _ -> wrap imported
    | Public_raw _ -> wrap imported
    | Public_spki _ -> wrap imported
    | Public_jwk _ -> wrap imported
    | Private_pkcs8 _ -> wrap imported
    | Private_jwk _ -> wrap imported

  let aes_bits who = function
    | None -> 256
    | Some ((128 | 192 | 256) as n) -> n
    | Some n ->
        invalid_arg
          (Printf.sprintf "%s: %d bits, expected 128, 192 or 256" who n)

  let generate (type k) ?(extractable = false) ?bits (a : k secret_algorithm) :
      k t =
    let who = "Workero.Crypto.Key.generate" in
    let length =
      match (a, bits) with
      | Hmac _, None -> []
      | Hmac _, Some n when n > 0 -> [ ("length", js_int n) ]
      | Hmac _, Some n ->
          invalid_arg
            (Printf.sprintf "%s: %d bits, expected a positive number" who n)
      | _ -> [ ("length", js_int (aes_bits who bits)) ]
    in
    wrap
      (subtle_call ~decode:Decode.js "generateKey"
         [|
           obj (secret_params a @ length);
           js_bool extractable;
           usages (secret_usages a);
         |])

  let generate_pair (type a) ?(extractable = false) ?modulus_bits
      (algorithm : a pair_algorithm) : a pair =
    let who = "Workero.Crypto.Key.generate_pair" in
    let rsa =
      match (is_rsa algorithm, modulus_bits) with
      | true, bits ->
          let bits = Option.value bits ~default:2048 in
          if bits < 512 then
            invalid_arg
              (Printf.sprintf "%s: %d modulus bits, expected at least 512" who
                 bits);
          [
            ("modulusLength", js_int bits);
            ("publicExponent", bytes "\x01\x00\x01");
          ]
      | false, None -> []
      | false, Some _ ->
          invalid_arg (who ^ ": modulus_bits is for RSA algorithms only")
    in
    let pair =
      subtle_call ~decode:Decode.js "generateKey"
        [|
          obj (pair_params algorithm @ rsa);
          js_bool extractable;
          usages (public_usages algorithm @ private_usages algorithm);
        |]
    in
    {
      public = wrap (Js.Unsafe.get pair "publicKey");
      private_ = wrap (Js.Unsafe.get pair "privateKey");
    }

  let export format key =
    subtle_call ~decode:Decode.bytes "exportKey" [| js_str format; key.js |]

  let export_raw key = export "raw" key
  let export_spki key = export "spki" key
  let export_pkcs8 key = export "pkcs8" key

  let export_jwk key =
    json_stringify
      (subtle_call ~decode:Decode.js "exportKey" [| js_str "jwk"; key.js |])

  let extractable key = Js.to_bool (Js.Unsafe.get key.js "extractable")
end

let or_none f =
  match f () with
  | v -> Some v
  | exception Promise.Js_error e
    when Internal.get_string (Promise.error_to_js e) "name"
         = Some "OperationError" ->
      None

let hmac_sign key data =
  subtle_call ~decode:Decode.bytes "sign"
    [| js_str "HMAC"; key.Key.js; bytes data |]

let hmac_verify key ~signature data =
  subtle_call ~decode:Decode.bool "verify"
    [| js_str "HMAC"; key.Key.js; bytes signature; bytes data |]

let gcm_params ~who ~iv aad =
  if iv = "" then invalid_arg (who ^ ": empty iv");
  obj
    ([ ("name", js_str "AES-GCM"); ("iv", bytes iv) ]
    @ match aad with Some a -> [ ("additionalData", bytes a) ] | None -> [])

let aes_gcm_encrypt key ~iv ?aad plain =
  let params = gcm_params ~who:"Workero.Crypto.aes_gcm_encrypt" ~iv aad in
  subtle_call ~decode:Decode.bytes "encrypt"
    [| params; key.Key.js; bytes plain |]

let aes_gcm_decrypt key ~iv ?aad data =
  let params = gcm_params ~who:"Workero.Crypto.aes_gcm_decrypt" ~iv aad in
  or_none (fun () ->
      subtle_call ~decode:Decode.bytes "decrypt"
        [| params; key.Key.js; bytes data |])

let derive_bits ~who ~kdf ~length ~params password =
  if length <= 0 then invalid_arg (who ^ ": length must be positive");
  let key =
    subtle_call ~decode:Decode.js "importKey"
      [|
        js_str "raw";
        bytes password;
        js_str kdf;
        Js.Unsafe.inject Js._false;
        Js.Unsafe.inject (Js.array [| Js.string "deriveBits" |]);
      |]
  in
  subtle_call ~decode:Decode.bytes "deriveBits"
    [|
      obj (("name", js_str kdf) :: params);
      key;
      Js.Unsafe.inject (Js.float (float_of_int (length * 8)));
    |]

let pbkdf2 hash ~password ~salt ~iterations ~length =
  if iterations <= 0 then
    invalid_arg "Workero.Crypto.pbkdf2: iterations must be positive";
  derive_bits ~who:"Workero.Crypto.pbkdf2" ~kdf:"PBKDF2" ~length
    ~params:
      [
        ("hash", js_str (hash_name hash));
        ("salt", bytes salt);
        ("iterations", Js.Unsafe.inject (Js.float (float_of_int iterations)));
      ]
    password

let hkdf hash ~key ~salt ~info ~length =
  derive_bits ~who:"Workero.Crypto.hkdf" ~kdf:"HKDF" ~length
    ~params:
      [
        ("hash", js_str (hash_name hash));
        ("salt", bytes salt);
        ("info", bytes info);
      ]
    key

let sign ~algorithm (key : _ Key.t) data =
  subtle_call ~decode:Decode.bytes "sign" [| algorithm; key.js; bytes data |]

let verify ~algorithm (key : _ Key.t) ~signature data =
  subtle_call ~decode:Decode.bool "verify"
    [| algorithm; key.js; bytes signature; bytes data |]

let rsassa_pkcs1_sign key data =
  sign ~algorithm:(js_str "RSASSA-PKCS1-v1_5") key data

let rsassa_pkcs1_verify key ~signature data =
  verify ~algorithm:(js_str "RSASSA-PKCS1-v1_5") key ~signature data

let pss_params ~who ~salt_length =
  if salt_length < 0 then invalid_arg (who ^ ": negative salt_length");
  obj [ ("name", js_str "RSA-PSS"); ("saltLength", js_int salt_length) ]

let rsa_pss_sign key ~salt_length data =
  let algorithm = pss_params ~who:"Workero.Crypto.rsa_pss_sign" ~salt_length in
  sign ~algorithm key data

let rsa_pss_verify key ~salt_length ~signature data =
  let algorithm =
    pss_params ~who:"Workero.Crypto.rsa_pss_verify" ~salt_length
  in
  verify ~algorithm key ~signature data

let oaep_params label =
  obj
    ([ ("name", js_str "RSA-OAEP") ]
    @ match label with Some l -> [ ("label", bytes l) ] | None -> [])

let rsa_oaep_encrypt (key : _ Key.t) ?label plain =
  subtle_call ~decode:Decode.bytes "encrypt"
    [| oaep_params label; key.js; bytes plain |]

let rsa_oaep_decrypt (key : _ Key.t) ?label data =
  or_none (fun () ->
      subtle_call ~decode:Decode.bytes "decrypt"
        [| oaep_params label; key.js; bytes data |])

let ecdsa_params hash =
  obj [ ("name", js_str "ECDSA"); ("hash", js_str (hash_name hash)) ]

let ecdsa_sign hash key data = sign ~algorithm:(ecdsa_params hash) key data

let ecdsa_verify hash key ~signature data =
  verify ~algorithm:(ecdsa_params hash) key ~signature data

let ed25519_sign key data = sign ~algorithm:(js_str "Ed25519") key data

let ed25519_verify key ~signature data =
  String.length signature = 64
  && verify ~algorithm:(js_str "Ed25519") key ~signature data

let agree ~who ~name (private_ : _ Key.t) ~(public : _ Key.t) ~length =
  if length <= 0 then invalid_arg (who ^ ": length must be positive");
  subtle_call ~decode:Decode.bytes "deriveBits"
    [|
      obj [ ("name", js_str name); ("public", public.js) ];
      private_.js;
      js_int (length * 8);
    |]

let ecdh_derive_bits key ~public ~length =
  agree ~who:"Workero.Crypto.ecdh_derive_bits" ~name:"ECDH" key ~public ~length

let x25519_derive_bits key ~public ~length =
  agree ~who:"Workero.Crypto.x25519_derive_bits" ~name:"X25519" key ~public
    ~length

let aes_cbc_params ~who ~iv =
  if String.length iv <> 16 then
    invalid_arg
      (Printf.sprintf "%s: iv is %d bytes, expected 16" who (String.length iv));
  obj [ ("name", js_str "AES-CBC"); ("iv", bytes iv) ]

let aes_cbc_encrypt (key : _ Key.t) ~iv plain =
  let params = aes_cbc_params ~who:"Workero.Crypto.aes_cbc_encrypt" ~iv in
  subtle_call ~decode:Decode.bytes "encrypt" [| params; key.js; bytes plain |]

let aes_cbc_decrypt (key : _ Key.t) ~iv data =
  let params = aes_cbc_params ~who:"Workero.Crypto.aes_cbc_decrypt" ~iv in
  or_none (fun () ->
      subtle_call ~decode:Decode.bytes "decrypt"
        [| params; key.js; bytes data |])

let aes_ctr_params ~who ~counter ~counter_bits =
  if String.length counter <> 16 then
    invalid_arg
      (Printf.sprintf "%s: counter is %d bytes, expected 16" who
         (String.length counter));
  if counter_bits < 1 || counter_bits > 128 then
    invalid_arg
      (Printf.sprintf "%s: counter_bits is %d, expected 1 to 128" who
         counter_bits);
  obj
    [
      ("name", js_str "AES-CTR");
      ("counter", bytes counter);
      ("length", js_int counter_bits);
    ]

let aes_ctr_encrypt (key : _ Key.t) ~counter ~counter_bits plain =
  let params =
    aes_ctr_params ~who:"Workero.Crypto.aes_ctr_encrypt" ~counter ~counter_bits
  in
  subtle_call ~decode:Decode.bytes "encrypt" [| params; key.js; bytes plain |]

let aes_ctr_decrypt (key : _ Key.t) ~counter ~counter_bits data =
  let params =
    aes_ctr_params ~who:"Workero.Crypto.aes_ctr_decrypt" ~counter ~counter_bits
  in
  subtle_call ~decode:Decode.bytes "decrypt" [| params; key.js; bytes data |]

type format = Raw | Jwk | Pkcs8 | Spki
type wrapping = |
type unwrapping = |

type _ wrapper =
  | Aes_kw : Key.aes_kw Key.t -> 'role wrapper
  | Aes_gcm : {
      key : Key.aes_gcm Key.t;
      iv : string;
      aad : string option;
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

let wrapper_args : type role.
    who:string -> role wrapper -> Internal.js * Internal.js =
 fun ~who -> function
  | Aes_kw key -> (js_str "AES-KW", key.js)
  | Aes_gcm { key; iv; aad } -> (gcm_params ~who ~iv aad, key.js)
  | Rsa_oaep_wrap { key; label } -> (oaep_params label, key.js)
  | Rsa_oaep_unwrap { key; label } -> (oaep_params label, key.js)

let format_name = function
  | Raw -> "raw"
  | Jwk -> "jwk"
  | Pkcs8 -> "pkcs8"
  | Spki -> "spki"

let wrap_key wrapper ~format (key : _ Key.t) =
  let algorithm, wrapping_key =
    wrapper_args ~who:"Workero.Crypto.wrap_key" wrapper
  in
  subtle_call ~decode:Decode.bytes "wrapKey"
    [| js_str (format_name format); key.js; wrapping_key; algorithm |]

let unwrap_key (type r) ?(extractable = false) (wrapper : unwrapping wrapper)
    (spec : r Key.import) wrapped : r =
  let algorithm, unwrapping_key =
    wrapper_args ~who:"Workero.Crypto.unwrap_key" wrapper
  in
  let format, key_algorithm, usages = Key.import_target spec in
  let unwrapped =
    subtle_call ~decode:Decode.js "unwrapKey"
      [|
        js_str format;
        bytes wrapped;
        unwrapping_key;
        algorithm;
        key_algorithm;
        js_bool extractable;
        Key.usages usages;
      |]
  in
  match spec with
  | Secret_raw _ -> Key.wrap unwrapped
  | Secret_jwk _ -> Key.wrap unwrapped
  | Public_raw _ -> Key.wrap unwrapped
  | Public_spki _ -> Key.wrap unwrapped
  | Public_jwk _ -> Key.wrap unwrapped
  | Private_pkcs8 _ -> Key.wrap unwrapped
  | Private_jwk _ -> Key.wrap unwrapped

module Digest_stream = struct
  type t = Internal.js

  let create hash =
    Js.Unsafe.new_obj
      (Js.Unsafe.get (crypto ()) "DigestStream")
      [| js_str (hash_name hash) |]

  let writer t = Stream.Writer.of_js (Internal.meth t "getWriter" [||])

  let digest t =
    Promise.await
      (Promise.of_js ~decode:Decode.bytes (Js.Unsafe.get t "digest"))
end
