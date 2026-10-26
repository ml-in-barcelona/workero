open Workero

let hex s =
  String.concat ""
    (List.init (String.length s) (fun i ->
         Printf.sprintf "%02x" (Char.code s.[i])))

let unhex h =
  String.init
    (String.length h / 2)
    (fun i -> Char.chr (int_of_string ("0x" ^ String.sub h (2 * i) 2)))

let hashes = Crypto.[ Sha1; Sha256; Sha384; Sha512 ]

module K = Crypto.Key

let contains sub s =
  let n = String.length sub in
  let rec go i =
    i + n <= String.length s && (String.sub s i n = sub || go (i + 1))
  in
  go 0

let verdict f =
  match f () with
  | b -> string_of_bool b
  | exception Invalid_argument _ -> "invalid"
  | exception Js_error _ -> "js_error"

let rejected f =
  match f () with
  | _ -> "no error"
  | exception Invalid_argument _ -> "invalid"
  | exception Js_error _ -> "js_error"

let handle req _env _ctx =
  match URL.path (Request.url req) with
  | "/subtle/digest" ->
      let line data =
        String.concat ","
          (List.map (fun h -> hex (Crypto.digest h data)) hashes)
      in
      Some (Response.text (line "abc" ^ "\n" ^ line ""))
  | "/subtle/digest-binary" ->
      Some (Response.text (hex (Crypto.digest Crypto.Sha256 (unhex "00ff80"))))
  | "/subtle/hmac" ->
      let sign hash key data =
        hex (Crypto.hmac_sign (Crypto.Key.import_hmac hash key) data)
      in
      let tc1 = String.make 20 '\x0b' and data1 = "Hi There" in
      let data2 = "what do ya want for nothing?" in
      Some
        (Response.text
           (String.concat "\n"
              [
                sign Crypto.Sha256 tc1 data1;
                sign Crypto.Sha512 tc1 data1;
                sign Crypto.Sha256 "Jefe" data2;
                sign Crypto.Sha384 "Jefe" data2;
                sign Crypto.Sha512 "Jefe" data2;
              ]))
  | "/subtle/hmac-verify" ->
      let key = Crypto.Key.import_hmac Crypto.Sha256 "Jefe" in
      let data = "what do ya want for nothing?" in
      let good =
        unhex "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
      in
      let bad = String.make 32 '\000' in
      let ok signature data =
        string_of_bool (Crypto.hmac_verify key ~signature data)
      in
      Some
        (Response.text
           (String.concat ","
              [
                ok good data;
                ok bad data;
                ok good (data ^ "!");
                ok (String.sub good 0 31) data;
                rejected (fun () -> Crypto.Key.import_hmac Crypto.Sha256 "");
              ]))
  | "/subtle/aes-gcm" ->
      let run key iv plain =
        let key = Crypto.Key.import_aes_gcm (unhex key) in
        let sealed = Crypto.aes_gcm_encrypt key ~iv:(unhex iv) (unhex plain) in
        let opened = Crypto.aes_gcm_decrypt key ~iv:(unhex iv) sealed in
        hex sealed ^ ";" ^ match opened with Some p -> hex p | None -> "none"
      in
      let key3 = "feffe9928665731c6d6a8f9467308308" in
      let iv3 = "cafebabefacedbaddecaf888" in
      let plain3 =
        "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255"
      in
      Some
        (Response.text
           (run (String.make 32 '0') (String.make 24 '0') ""
           ^ "\n" ^ run key3 iv3 plain3))
  | "/subtle/aes-gcm-fail" ->
      let key = Crypto.Key.import_aes_gcm (String.make 16 'k') in
      let other = Crypto.Key.import_aes_gcm (String.make 16 'x') in
      let iv = String.make 12 'i' in
      let sealed = Crypto.aes_gcm_encrypt key ~iv ~aad:"header" "secret" in
      let flipped =
        String.mapi
          (fun i c -> if i = 0 then Char.chr (Char.code c lxor 1) else c)
          sealed
      in
      let show = function Some s -> s | None -> "none" in
      Some
        (Response.text
           (String.concat ","
              [
                show (Crypto.aes_gcm_decrypt key ~iv ~aad:"header" sealed);
                show (Crypto.aes_gcm_decrypt key ~iv sealed);
                show
                  (Crypto.aes_gcm_decrypt key ~iv:(String.make 12 'j')
                     ~aad:"header" sealed);
                show (Crypto.aes_gcm_decrypt other ~iv ~aad:"header" sealed);
                show (Crypto.aes_gcm_decrypt key ~iv ~aad:"header" flipped);
                rejected (fun () -> Crypto.Key.import_aes_gcm "short");
                rejected (fun () -> Crypto.aes_gcm_encrypt key ~iv:"" "x");
              ]))
  | "/subtle/pbkdf2" ->
      let derive iterations length =
        hex
          (Crypto.pbkdf2 Crypto.Sha1 ~password:"password" ~salt:"salt"
             ~iterations ~length)
      in
      Some
        (Response.text
           (String.concat ","
              [
                derive 1 20;
                derive 4096 20;
                rejected (fun () -> derive 0 20);
                rejected (fun () -> derive 1 0);
              ]))
  | "/subtle/hkdf" ->
      let okm =
        Crypto.hkdf Crypto.Sha256 ~key:(String.make 22 '\x0b')
          ~salt:(unhex "000102030405060708090a0b0c")
          ~info:(unhex "f0f1f2f3f4f5f6f7f8f9")
          ~length:42
      in
      Some
        (Response.text
           (String.concat ","
              [
                hex okm;
                rejected (fun () ->
                    Crypto.hkdf Crypto.Sha256 ~key:"k" ~salt:"" ~info:""
                      ~length:0);
                rejected (fun () ->
                    Crypto.hkdf Crypto.Sha256 ~key:"k" ~salt:"" ~info:""
                      ~length:8161);
              ]))
  | "/subtle/ed25519" ->
      let seed =
        "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
      in
      let public =
        "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
      in
      let private_key =
        K.import (K.Private_pkcs8 K.Ed25519)
          (unhex ("302e020100300506032b657004220420" ^ seed))
      in
      let spki =
        K.import (K.Public_spki K.Ed25519)
          (unhex ("302a300506032b6570032100" ^ public))
      in
      let raw = K.import (K.Public_raw K.Ed25519) (unhex public) in
      let signature = Crypto.ed25519_sign private_key "" in
      Some
        (Response.text
           (String.concat ","
              [
                hex signature;
                string_of_bool (Crypto.ed25519_verify spki ~signature "");
                string_of_bool (Crypto.ed25519_verify raw ~signature "");
                string_of_bool (Crypto.ed25519_verify raw ~signature "x");
                verdict (fun () ->
                    Crypto.ed25519_verify raw ~signature:"short" "");
              ]))
  | "/subtle/x25519" ->
      let alice =
        K.import (K.Private_jwk K.X25519) Crypto_vectors.x25519_jwk_alice
      in
      let alice_public =
        K.import (K.Public_raw K.X25519)
          (unhex
             "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
      in
      let bob =
        K.import (K.Private_pkcs8 K.X25519)
          (unhex
             ("302e020100300506032b656e04220420"
            ^ "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb"
             ))
      in
      let bob_public =
        K.import (K.Public_raw K.X25519)
          (unhex
             "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")
      in
      Some
        (Response.text
           (String.concat ","
              [
                hex
                  (Crypto.x25519_derive_bits alice ~public:bob_public ~length:32);
                hex
                  (Crypto.x25519_derive_bits bob ~public:alice_public ~length:32);
                rejected (fun () ->
                    Crypto.x25519_derive_bits alice ~public:bob_public ~length:0);
              ]))
  | "/subtle/ecdsa" ->
      let private_key =
        K.import (K.Private_jwk (K.Ecdsa Crypto.P256))
          Crypto_vectors.p256_jwk_private
      in
      let public_key =
        K.import (K.Public_jwk (K.Ecdsa Crypto.P256))
          Crypto_vectors.p256_jwk_public
      in
      let raw_public =
        K.import (K.Public_raw (K.Ecdsa Crypto.P256))
          (unhex
             ("04"
            ^ "60fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb6"
            ^ "7903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299"
             ))
      in
      let fixed =
        unhex
          "efd48b2aacb6a8fd1140dd9cd45e81d69d2c877b56aaf991c34d0ea84eaf3716f7cb1c942d657c41d436c7a1b6e29f65f3e900dbb9aff4064dc4ab2f843acda8"
      in
      let signed = Crypto.ecdsa_sign Crypto.Sha256 private_key "sample" in
      let pair = K.generate_pair (K.Ecdsa Crypto.P384) in
      let signed384 = Crypto.ecdsa_sign Crypto.Sha384 pair.private_ "sample" in
      Some
        (Response.text
           (String.concat ","
              [
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha256 public_key
                      ~signature:fixed "sample");
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha256 raw_public
                      ~signature:fixed "sample");
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha256 public_key
                      ~signature:fixed "other");
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha384 public_key
                      ~signature:fixed "sample");
                string_of_int (String.length signed);
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha256 public_key
                      ~signature:signed "sample");
                string_of_int (String.length signed384);
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha384 pair.public
                      ~signature:signed384 "sample");
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha384 pair.public
                      ~signature:"short" "sample");
              ]))
  | "/subtle/ecdh" ->
      let agree curve length =
        let a = K.generate_pair (K.Ecdh curve) in
        let b = K.generate_pair (K.Ecdh curve) in
        let ab = Crypto.ecdh_derive_bits a.private_ ~public:b.public ~length in
        let ba = Crypto.ecdh_derive_bits b.private_ ~public:a.public ~length in
        Printf.sprintf "%d:%b" (String.length ab) (ab = ba)
      in
      let a = K.generate_pair (K.Ecdh Crypto.P256) in
      Some
        (Response.text
           (String.concat ","
              [
                agree Crypto.P256 32;
                agree Crypto.P384 48;
                agree Crypto.P521 66;
                agree Crypto.P256 16;
                rejected (fun () ->
                    Crypto.ecdh_derive_bits a.private_ ~public:a.public
                      ~length:0);
              ]))
  | "/subtle/rsa-pkcs1" ->
      let data = "workero rsa vector" in
      let signature = unhex Crypto_vectors.rsa_signature_hex in
      let alg = K.Rsassa_pkcs1_v1_5 Crypto.Sha256 in
      let spki =
        K.import (K.Public_spki alg) (unhex Crypto_vectors.rsa_spki_hex)
      in
      let jwk = K.import (K.Public_jwk alg) Crypto_vectors.rsa_jwk_public in
      let pkcs8 =
        K.import (K.Private_pkcs8 alg) (unhex Crypto_vectors.rsa_pkcs8_hex)
      in
      let jwk_private =
        K.import (K.Private_jwk alg) Crypto_vectors.rsa_jwk_private
      in
      Some
        (Response.text
           (String.concat ","
              [
                verdict (fun () ->
                    Crypto.rsassa_pkcs1_verify spki ~signature data);
                verdict (fun () ->
                    Crypto.rsassa_pkcs1_verify jwk ~signature data);
                verdict (fun () ->
                    Crypto.rsassa_pkcs1_verify spki ~signature "other");
                verdict (fun () ->
                    Crypto.rsassa_pkcs1_verify spki ~signature:"short" data);
                string_of_bool (Crypto.rsassa_pkcs1_sign pkcs8 data = signature);
                string_of_bool
                  (Crypto.rsassa_pkcs1_sign jwk_private data = signature);
                rejected (fun () ->
                    K.import (K.Public_raw alg) Crypto_vectors.rsa_spki_hex);
                rejected (fun () -> K.import (K.Public_spki alg) "not a key");
              ]))
  | "/subtle/rsa-pss-oaep" ->
      let pss = K.generate_pair ~modulus_bits:1024 (K.Rsa_pss Crypto.Sha256) in
      let signature = Crypto.rsa_pss_sign pss.private_ ~salt_length:32 "msg" in
      let oaep =
        K.generate_pair ~modulus_bits:1024 (K.Rsa_oaep Crypto.Sha256)
      in
      let other =
        K.generate_pair ~modulus_bits:1024 (K.Rsa_oaep Crypto.Sha256)
      in
      let sealed = Crypto.rsa_oaep_encrypt oaep.public ~label:"l" "secret" in
      let show = function Some s -> s | None -> "none" in
      Some
        (Response.text
           (String.concat ","
              [
                string_of_int (String.length signature);
                verdict (fun () ->
                    Crypto.rsa_pss_verify pss.public ~salt_length:32 ~signature
                      "msg");
                verdict (fun () ->
                    Crypto.rsa_pss_verify pss.public ~salt_length:32 ~signature
                      "other");
                verdict (fun () ->
                    Crypto.rsa_pss_verify pss.public ~salt_length:0 ~signature
                      "msg");
                verdict (fun () ->
                    Crypto.rsa_pss_sign pss.private_ ~salt_length:(-1) "msg"
                    = "");
                string_of_int (String.length sealed);
                show (Crypto.rsa_oaep_decrypt oaep.private_ ~label:"l" sealed);
                show (Crypto.rsa_oaep_decrypt oaep.private_ sealed);
                show (Crypto.rsa_oaep_decrypt other.private_ ~label:"l" sealed);
                show
                  (Crypto.rsa_oaep_decrypt oaep.private_
                     (Crypto.rsa_oaep_encrypt oaep.public "plain"));
                rejected (fun () ->
                    Crypto.rsa_oaep_encrypt oaep.public (String.make 100 'x'));
              ]))
  | "/subtle/aes-cbc" ->
      let key =
        K.import (K.Secret_raw K.Aes_cbc)
          (unhex "2b7e151628aed2a6abf7158809cf4f3c")
      in
      let iv = unhex "000102030405060708090a0b0c0d0e0f" in
      let plain =
        unhex
          "6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710"
      in
      let sealed = Crypto.aes_cbc_encrypt key ~iv plain in
      let other = K.import (K.Secret_raw K.Aes_cbc) (String.make 16 '\000') in
      Some
        (Response.text
           (String.concat ","
              [
                string_of_int (String.length sealed);
                hex (String.sub sealed 0 64);
                (match Crypto.aes_cbc_decrypt key ~iv sealed with
                | Some p -> string_of_bool (p = plain)
                | None -> "none");
                (match
                   Crypto.aes_cbc_decrypt key ~iv (String.sub sealed 0 17)
                 with
                | Some _ -> "some"
                | None -> "none");
                (match Crypto.aes_cbc_decrypt other ~iv sealed with
                | Some p -> string_of_bool (p = plain)
                | None -> "none");
                rejected (fun () -> Crypto.aes_cbc_encrypt key ~iv:"short" "x");
              ]))
  | "/subtle/aes-ctr" ->
      let key =
        K.import (K.Secret_raw K.Aes_ctr)
          (unhex "2b7e151628aed2a6abf7158809cf4f3c")
      in
      let counter = unhex "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff" in
      let plain =
        unhex
          "6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710"
      in
      let sealed =
        Crypto.aes_ctr_encrypt key ~counter ~counter_bits:128 plain
      in
      Some
        (Response.text
           (String.concat ","
              [
                hex sealed;
                string_of_bool
                  (Crypto.aes_ctr_decrypt key ~counter ~counter_bits:128 sealed
                  = plain);
                rejected (fun () ->
                    Crypto.aes_ctr_encrypt key ~counter ~counter_bits:0 "x");
                rejected (fun () ->
                    Crypto.aes_ctr_encrypt key ~counter:"short" ~counter_bits:64
                      "x");
              ]))
  | "/subtle/wrap" ->
      let kek =
        K.import ~extractable:true (K.Secret_raw K.Aes_kw)
          (unhex "000102030405060708090a0b0c0d0e0f")
      in
      let data = unhex "00112233445566778899aabbccddeeff" in
      let key = K.import ~extractable:true (K.Secret_raw K.Aes_gcm) data in
      let wrapped =
        Crypto.wrap_key (Crypto.Aes_kw kek) ~format:Crypto.Raw key
      in
      let unwrapped =
        Crypto.unwrap_key ~extractable:true (Crypto.Aes_kw kek)
          (K.Secret_raw K.Aes_gcm) wrapped
      in
      let hmac = K.generate ~extractable:true (K.Hmac Crypto.Sha256) in
      let gcm = K.generate K.Aes_gcm in
      let iv = String.make 12 'i' in
      let by_gcm iv = Crypto.Aes_gcm { key = gcm; iv; aad = Some "aad" } in
      let sealed = Crypto.wrap_key (by_gcm iv) ~format:Crypto.Jwk hmac in
      let reopened =
        Crypto.unwrap_key (by_gcm iv) (K.Secret_jwk (K.Hmac Crypto.Sha256))
          sealed
      in
      let oaep =
        K.generate_pair ~modulus_bits:1024 (K.Rsa_oaep Crypto.Sha256)
      in
      let aes = K.generate ~extractable:true ~bits:128 K.Aes_gcm in
      let by_rsa_wrap =
        Crypto.Rsa_oaep_wrap { key = oaep.public; label = None }
      in
      let by_rsa_unwrap =
        Crypto.Rsa_oaep_unwrap { key = oaep.private_; label = None }
      in
      let rsa_wrapped = Crypto.wrap_key by_rsa_wrap ~format:Crypto.Raw aes in
      let rsa_unwrapped =
        Crypto.unwrap_key ~extractable:true by_rsa_unwrap
          (K.Secret_raw K.Aes_gcm) rsa_wrapped
      in
      Some
        (Response.text
           (String.concat ","
              [
                hex wrapped;
                hex (K.export_raw unwrapped);
                string_of_bool (K.extractable unwrapped);
                string_of_bool
                  (Crypto.hmac_sign reopened "x" = Crypto.hmac_sign hmac "x");
                rejected (fun () ->
                    ignore
                      (Crypto.unwrap_key
                         (by_gcm (String.make 12 'j'))
                         (K.Secret_jwk (K.Hmac Crypto.Sha256)) sealed);
                    ());
                rejected (fun () ->
                    ignore (Crypto.wrap_key (by_gcm "") ~format:Crypto.Raw hmac);
                    ());
                rejected (fun () ->
                    ignore
                      (Crypto.wrap_key (Crypto.Aes_kw kek) ~format:Crypto.Raw
                         (K.generate K.Aes_gcm));
                    ());
                string_of_int (String.length rsa_wrapped);
                string_of_bool (K.export_raw rsa_unwrapped = K.export_raw aes);
              ]))
  | "/subtle/key-export" ->
      let aes = K.generate ~extractable:true K.Aes_gcm in
      let raw = K.export_raw aes in
      let again = K.import ~extractable:true (K.Secret_raw K.Aes_gcm) raw in
      let kept = K.generate K.Aes_gcm in
      let ec = K.generate_pair ~extractable:true (K.Ecdsa Crypto.P256) in
      let spki = K.export_spki ec.public in
      let pkcs8 = K.export_pkcs8 ec.private_ in
      let alg = K.Ecdsa Crypto.P256 in
      let from_spki = K.import ~extractable:true (K.Public_spki alg) spki in
      let from_jwk = K.import (K.Private_jwk alg) (K.export_jwk ec.private_) in
      let signature = Crypto.ecdsa_sign Crypto.Sha256 from_jwk "m" in
      let locked = K.generate_pair K.Ed25519 in
      let jwk = K.export_jwk aes in
      Some
        (Response.text
           (String.concat ","
              [
                string_of_int (String.length raw);
                string_of_bool (contains {|"kty":"oct"|} jwk);
                string_of_bool (K.extractable aes);
                string_of_bool (K.extractable kept);
                string_of_bool (K.extractable again);
                string_of_bool (K.export_raw again = raw);
                rejected (fun () ->
                    ignore (K.export_raw kept);
                    ());
                string_of_bool (K.export_spki from_spki = spki);
                string_of_bool (String.length pkcs8 > 0);
                verdict (fun () ->
                    Crypto.ecdsa_verify Crypto.Sha256 ec.public ~signature "m");
                string_of_int (String.length (K.export_raw locked.public));
                rejected (fun () ->
                    ignore (K.export_pkcs8 locked.private_);
                    ());
                rejected (fun () ->
                    ignore (K.export_jwk kept);
                    ());
                rejected (fun () ->
                    ignore (K.export_raw ec.private_);
                    ());
              ]))
  | "/subtle/generate" ->
      let hmac = K.generate (K.Hmac Crypto.Sha256) in
      let hmac512 =
        K.generate ~extractable:true ~bits:512 (K.Hmac Crypto.Sha256)
      in
      let aes128 = K.generate ~extractable:true ~bits:128 K.Aes_ctr in
      let aes_default = K.generate ~extractable:true K.Aes_cbc in
      let rsa =
        K.generate_pair ~extractable:true ~modulus_bits:1024
          (K.Rsassa_pkcs1_v1_5 Crypto.Sha256)
      in
      Some
        (Response.text
           (String.concat ","
              [
                string_of_int (String.length (Crypto.hmac_sign hmac "x"));
                string_of_int (String.length (K.export_raw hmac512));
                string_of_int (String.length (K.export_raw aes128));
                string_of_int (String.length (K.export_raw aes_default));
                string_of_int
                  (String.length (Crypto.rsassa_pkcs1_sign rsa.private_ "x"));
                rejected (fun () ->
                    ignore (K.generate ~bits:100 K.Aes_gcm);
                    ());
                rejected (fun () ->
                    ignore (K.generate ~bits:0 (K.Hmac Crypto.Sha256));
                    ());
                rejected (fun () ->
                    ignore (K.generate_pair ~modulus_bits:2048 K.Ed25519);
                    ());
                rejected (fun () ->
                    ignore
                      (K.generate_pair ~modulus_bits:128
                         (K.Rsa_pss Crypto.Sha256));
                    ());
              ]))
  | "/subtle/digest-stream" ->
      let run hash =
        let stream = Crypto.Digest_stream.create hash in
        let writer = Crypto.Digest_stream.writer stream in
        Stream.Writer.write writer "a";
        Stream.Writer.write writer "bc";
        Stream.Writer.close writer;
        hex (Crypto.Digest_stream.digest stream)
      in
      Some
        (Response.text
           (String.concat ","
              [
                run Crypto.Sha256;
                run Crypto.Sha1;
                string_of_bool
                  (run Crypto.Sha512 = hex (Crypto.digest Crypto.Sha512 "abc"));
              ]))
  | "/subtle/timing-safe-equal" ->
      let mac =
        unhex "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
      in
      let flipped =
        String.mapi
          (fun i c -> if i = 31 then Char.chr (Char.code c lxor 1) else c)
          mac
      in
      let eq a b = string_of_bool (Crypto.timing_safe_equal a b) in
      Some
        (Response.text
           (String.concat ","
              [
                eq mac (unhex (hex mac));
                eq mac flipped;
                eq mac (String.sub mac 0 31);
                eq "" "";
                eq "\000\255" "\000\255";
                eq "\000\255" "\000\254";
              ]))
  | "/subtle/derive-key" ->
      let raw k = hex (K.export_raw k) in
      let pbkdf2 =
        Crypto.pbkdf2_key Crypto.Sha1 ~password:"password" ~salt:"salt"
          ~iterations:2 ~extractable:true ~bits:128 K.Aes_gcm
      in
      let okm_key = String.make 22 '\x0b' in
      let salt = unhex "000102030405060708090a0b0c" in
      let info = unhex "f0f1f2f3f4f5f6f7f8f9" in
      let hkdf_cbc =
        Crypto.hkdf_key Crypto.Sha256 ~key:okm_key ~salt ~info ~extractable:true
          ~bits:128 K.Aes_cbc
      in
      let hkdf_hmac =
        Crypto.hkdf_key Crypto.Sha256 ~key:okm_key ~salt ~info ~extractable:true
          ~bits:256 (K.Hmac Crypto.Sha256)
      in
      let locked =
        Crypto.hkdf_key Crypto.Sha256 ~key:okm_key ~salt ~info ~bits:128
          K.Aes_ctr
      in
      let alice =
        K.import (K.Private_jwk K.X25519) Crypto_vectors.x25519_jwk_alice
      in
      let bob_public =
        K.import (K.Public_raw K.X25519)
          (unhex
             "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")
      in
      let x25519 =
        Crypto.x25519_derive_key alice ~public:bob_public ~extractable:true
          ~bits:256 K.Aes_gcm
      in
      let a = K.generate_pair (K.Ecdh Crypto.P256) in
      let b = K.generate_pair (K.Ecdh Crypto.P256) in
      let ecdh_a =
        Crypto.ecdh_derive_key a.private_ ~public:b.public ~extractable:true
          ~bits:128 K.Aes_gcm
      in
      let ecdh_b =
        Crypto.ecdh_derive_key b.private_ ~public:a.public ~extractable:true
          ~bits:128 K.Aes_gcm
      in
      let sealed =
        Crypto.aes_gcm_encrypt ecdh_a ~iv:(String.make 12 'i') "shared"
      in
      Some
        (Response.text
           (String.concat ","
              [
                raw pbkdf2;
                raw hkdf_cbc;
                raw hkdf_hmac;
                raw x25519;
                string_of_bool (K.extractable locked);
                string_of_bool (K.extractable pbkdf2);
                rejected (fun () ->
                    ignore (K.export_raw locked);
                    ());
                string_of_bool (raw ecdh_a = raw ecdh_b);
                (match
                   Crypto.aes_gcm_decrypt ecdh_b ~iv:(String.make 12 'i') sealed
                 with
                | Some p -> p
                | None -> "none");
                rejected (fun () ->
                    ignore
                      (Crypto.pbkdf2_key Crypto.Sha1 ~password:"p" ~salt:"s"
                         ~iterations:0 K.Aes_gcm);
                    ());
                rejected (fun () ->
                    ignore
                      (Crypto.hkdf_key Crypto.Sha256 ~key:"k" ~salt:"" ~info:""
                         ~bits:100 K.Aes_gcm);
                    ());
                rejected (fun () ->
                    ignore
                      (Crypto.ecdh_derive_key a.private_ ~public:b.public
                         ~bits:0 (K.Hmac Crypto.Sha256));
                    ());
              ]))
  | "/subtle/wrap-aes-cbc-ctr" ->
      let kek_bytes = unhex "2b7e151628aed2a6abf7158809cf4f3c" in
      let data = unhex "6bc1bee22e409f96e93d7e117393172a" in
      let target = K.import ~extractable:true (K.Secret_raw K.Aes_gcm) data in
      let cbc_key = K.import (K.Secret_raw K.Aes_cbc) kek_bytes in
      let cbc () =
        Crypto.Aes_cbc
          { key = cbc_key; iv = unhex "000102030405060708090a0b0c0d0e0f" }
      in
      let cbc_wrapped = Crypto.wrap_key (cbc ()) ~format:Crypto.Raw target in
      let cbc_back =
        Crypto.unwrap_key ~extractable:true (cbc ()) (K.Secret_raw K.Aes_gcm)
          cbc_wrapped
      in
      let ctr_key = K.import (K.Secret_raw K.Aes_ctr) kek_bytes in
      let ctr () =
        Crypto.Aes_ctr
          {
            key = ctr_key;
            counter = unhex "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff";
            counter_bits = 128;
          }
      in
      let ctr_wrapped = Crypto.wrap_key (ctr ()) ~format:Crypto.Raw target in
      let ctr_back =
        Crypto.unwrap_key ~extractable:true (ctr ()) (K.Secret_raw K.Aes_gcm)
          ctr_wrapped
      in
      Some
        (Response.text
           (String.concat ","
              [
                string_of_int (String.length cbc_wrapped);
                hex (String.sub cbc_wrapped 0 16);
                hex (K.export_raw cbc_back);
                hex ctr_wrapped;
                hex (K.export_raw ctr_back);
                rejected (fun () ->
                    ignore
                      (Crypto.wrap_key
                         (Crypto.Aes_cbc { key = cbc_key; iv = "short" })
                         ~format:Crypto.Raw target);
                    ());
                rejected (fun () ->
                    ignore
                      (Crypto.wrap_key
                         (Crypto.Aes_ctr
                            {
                              key = ctr_key;
                              counter = String.make 16 'c';
                              counter_bits = 0;
                            })
                         ~format:Crypto.Raw target);
                    ());
              ]))
  | "/subtle/rsa-public-exponent" ->
      let exponent pair =
        let jwk = K.export_jwk pair.K.public in
        if contains {|"e":"Aw"|} jwk then "3"
        else if contains {|"e":"AQAB"|} jwk then "65537"
        else "other"
      in
      let alg = K.Rsassa_pkcs1_v1_5 Crypto.Sha256 in
      let three =
        K.generate_pair ~extractable:true ~modulus_bits:1024 ~public_exponent:3
          alg
      in
      let default = K.generate_pair ~extractable:true ~modulus_bits:1024 alg in
      let explicit =
        K.generate_pair ~extractable:true ~modulus_bits:1024
          ~public_exponent:65537 alg
      in
      let signature = Crypto.rsassa_pkcs1_sign three.private_ "msg" in
      Some
        (Response.text
           (String.concat ","
              [
                exponent three;
                exponent default;
                exponent explicit;
                string_of_bool
                  (Crypto.rsassa_pkcs1_verify three.public ~signature "msg");
                rejected (fun () ->
                    ignore
                      (K.generate_pair ~modulus_bits:1024 ~public_exponent:17
                         alg);
                    ());
                rejected (fun () ->
                    ignore
                      (K.generate_pair ~modulus_bits:1024 ~public_exponent:0 alg);
                    ());
                rejected (fun () ->
                    ignore (K.generate_pair ~public_exponent:3 K.Ed25519);
                    ());
              ]))
  | "/subtle/key-properties" ->
      let list = String.concat "+" in
      let aes = K.generate K.Aes_gcm in
      let hmac = K.generate (K.Hmac Crypto.Sha256) in
      let ecdsa = K.generate_pair (K.Ecdsa Crypto.P256) in
      let ecdh = K.generate_pair (K.Ecdh Crypto.P384) in
      let oaep =
        K.generate_pair ~modulus_bits:1024 (K.Rsa_oaep Crypto.Sha256)
      in
      let imported = K.import (K.Secret_raw K.Aes_kw) (String.make 16 'k') in
      Some
        (Response.text
           (String.concat "\n"
              [
                K.algorithm aes;
                list (K.usages aes);
                K.algorithm hmac;
                list (K.usages hmac);
                K.algorithm ecdsa.private_;
                list (K.usages ecdsa.private_);
                list (K.usages ecdsa.public);
                K.algorithm ecdh.public;
                list (K.usages ecdh.private_);
                string_of_bool
                  (contains {|"name":"RSA-OAEP"|} (K.algorithm oaep.public));
                string_of_bool
                  (contains {|"modulusLength":1024|} (K.algorithm oaep.public));
                string_of_bool
                  (contains {|"hash":{"name":"SHA-256"}|}
                     (K.algorithm oaep.private_));
                list (K.usages oaep.public);
                list (K.usages oaep.private_);
                K.algorithm imported;
                list (K.usages imported);
              ]))
  | _ -> None
