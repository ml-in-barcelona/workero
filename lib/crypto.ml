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

let subtle () = Js.Unsafe.get (crypto ()) "subtle"
let js_str = Internal.str
let obj fields = Binding.options fields
let bytes = Wire.body_of_string
let subtle_call ~decode name args = Binding.call ~decode (subtle ()) name args

let digest hash data =
  subtle_call ~decode:Decode.bytes "digest"
    [| js_str (hash_name hash); bytes data |]

module Key = struct
  type 'kind t = Internal.js
  type hmac
  type aes_gcm

  let usages l =
    Js.Unsafe.inject (Js.array (Array.of_list (List.map Js.string l)))

  let import ~algorithm ~usages:u raw =
    subtle_call ~decode:Decode.js "importKey"
      [|
        js_str "raw"; bytes raw; algorithm; Js.Unsafe.inject Js._false; usages u;
      |]

  let import_hmac hash raw =
    if raw = "" then invalid_arg "Workero.Crypto.Key.import_hmac: empty key";
    import
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
    import
      ~algorithm:(obj [ ("name", js_str "AES-GCM") ])
      ~usages:[ "encrypt"; "decrypt" ] raw
end

let hmac_sign key data =
  subtle_call ~decode:Decode.bytes "sign" [| js_str "HMAC"; key; bytes data |]

let hmac_verify key ~signature data =
  subtle_call ~decode:Decode.bool "verify"
    [| js_str "HMAC"; key; bytes signature; bytes data |]

let gcm_params ~who ~iv aad =
  if iv = "" then invalid_arg (who ^ ": empty iv");
  obj
    ([ ("name", js_str "AES-GCM"); ("iv", bytes iv) ]
    @ match aad with Some a -> [ ("additionalData", bytes a) ] | None -> [])

let aes_gcm_encrypt key ~iv ?aad plain =
  let params = gcm_params ~who:"Workero.Crypto.aes_gcm_encrypt" ~iv aad in
  subtle_call ~decode:Decode.bytes "encrypt" [| params; key; bytes plain |]

let aes_gcm_decrypt key ~iv ?aad data =
  let params = gcm_params ~who:"Workero.Crypto.aes_gcm_decrypt" ~iv aad in
  match
    subtle_call ~decode:Decode.bytes "decrypt" [| params; key; bytes data |]
  with
  | plain -> Some plain
  | exception Promise.Js_error e
    when Internal.get_string (Promise.error_to_js e) "name"
         = Some "OperationError" ->
      None

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
