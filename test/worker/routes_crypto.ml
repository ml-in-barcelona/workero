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
  | _ -> None
