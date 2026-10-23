import { runCases } from "./lib.mjs";

const cases = [
  {
    name: "Crypto.digest matches the NIST vectors for abc and the empty string",
    request: ["http://test/subtle/digest"],
    status: 200,
    body: [
      "a9993e364706816aba3e25717850c26c9cd0d89d,ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad,cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7,ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
      "da39a3ee5e6b4b0d3255bfef95601890afd80709,e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855,38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b,cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
    ].join("\n"),
  },
  {
    name: "Crypto.digest hashes raw bytes, not text",
    request: ["http://test/subtle/digest-binary"],
    status: 200,
    body: "f742b965f156c10374bc23aea96e3a8aff8facd6fc079defeaa30219ad86f211",
  },
  {
    name: "Crypto.hmac_sign matches RFC 4231 test cases 1 and 2",
    request: ["http://test/subtle/hmac"],
    status: 200,
    body: [
      "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7",
      "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854",
      "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
      "af45d2e376484031617f78d2b58a6b1b9c7ef464f5a01b47e42ec3736322445e8e2240ca5e69e2c78b3239ecfab21649",
      "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737",
    ].join("\n"),
  },
  {
    name: "Crypto.hmac_verify accepts a good signature and rejects bad ones",
    request: ["http://test/subtle/hmac-verify"],
    status: 200,
    body: "true,false,false,false,invalid",
  },
  {
    name: "Crypto.aes_gcm_encrypt and decrypt match NIST GCM test cases 1 and 3",
    request: ["http://test/subtle/aes-gcm"],
    status: 200,
    body: [
      "58e2fccefa7e3061367f1d57a4e7455a;",
      "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f59854d5c2af327cd64a62cf35abd2ba6fab4;d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255",
    ].join("\n"),
  },
  {
    name: "Crypto.aes_gcm_decrypt gives None on a wrong key, iv, aad or changed data",
    request: ["http://test/subtle/aes-gcm-fail"],
    status: 200,
    body: "secret,none,none,none,none,invalid,invalid",
  },
  {
    name: "Crypto.pbkdf2 matches RFC 6070",
    request: ["http://test/subtle/pbkdf2"],
    status: 200,
    body: "0c60c80f961f0e71f3a9b524af6012062fe037a6,4b007901b765489abead49d926f721d065a429c1,invalid,invalid",
  },
  {
    name: "Crypto.hkdf matches RFC 5869 test case 1",
    request: ["http://test/subtle/hkdf"],
    status: 200,
    body: "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865,invalid,js_error",
  },
  {
    name: "Crypto Ed25519 matches RFC 8032 test 1 and imports spki, pkcs8 and raw keys",
    request: ["http://test/subtle/ed25519"],
    status: 200,
    body: "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b,true,true,false,false",
  },
  {
    name: "Crypto X25519 matches RFC 7748 section 6.1 from a jwk, pkcs8 and raw keys",
    request: ["http://test/subtle/x25519"],
    status: 200,
    body: "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742,4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742,invalid",
  },
  {
    name: "Crypto ECDSA verifies the RFC 6979 P-256 signature and round-trips on P-384",
    request: ["http://test/subtle/ecdsa"],
    status: 200,
    body: "true,true,false,false,64,true,96,true,false",
  },
  {
    name: "Crypto.ecdh_derive_bits agrees on P-256, P-384 and P-521",
    request: ["http://test/subtle/ecdh"],
    status: 200,
    body: "32:true,48:true,66:true,16:true,invalid",
  },
  {
    name: "Crypto RSASSA-PKCS1-v1_5 matches a fixed signature from spki, jwk and pkcs8 keys",
    request: ["http://test/subtle/rsa-pkcs1"],
    status: 200,
    body: "true,true,false,false,true,true,invalid,js_error",
  },
  {
    name: "Crypto RSA-PSS and RSA-OAEP round trip",
    request: ["http://test/subtle/rsa-pss-oaep"],
    status: 200,
    body: "128,true,false,false,invalid,128,secret,none,none,plain,js_error",
  },
  {
    name: "Crypto.aes_cbc_encrypt matches NIST SP 800-38A F.2.1",
    request: ["http://test/subtle/aes-cbc"],
    status: 200,
    body: "80,7649abac8119b246cee98e9b12e9197d5086cb9b507219ee95db113a917678b273bed6b8e3c1743b7116e69e222295163ff1caa1681fac09120eca307586e1a7,true,none,none,invalid",
  },
  {
    name: "Crypto.aes_ctr_encrypt matches NIST SP 800-38A F.5.1",
    request: ["http://test/subtle/aes-ctr"],
    status: 200,
    body: "874d6191b620e3261bef6864990db6ce9806f66b7970fdff8617187bb9fffdff5ae4df3edbd5d35e5b4f09020db03eab1e031dda2fbe03d1792170a0f3009cee,true,invalid,invalid",
  },
  {
    name: "Crypto.wrap_key matches RFC 3394 and wraps with AES-GCM and RSA-OAEP",
    request: ["http://test/subtle/wrap"],
    status: 200,
    body: "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5,00112233445566778899aabbccddeeff,true,true,js_error,invalid,js_error,128,true",
  },
  {
    name: "Crypto.Key exports extractable keys and rejects the rest",
    request: ["http://test/subtle/key-export"],
    status: 200,
    body: "32,true,true,false,true,true,js_error,true,true,true,32,js_error,js_error,js_error",
  },
  {
    name: "Crypto.Key.generate and generate_pair check their arguments",
    request: ["http://test/subtle/generate"],
    status: 200,
    body: "32,64,16,32,128,invalid,invalid,invalid,invalid",
  },
  {
    name: "Crypto.Digest_stream hashes what is written to it",
    request: ["http://test/subtle/digest-stream"],
    status: 200,
    body: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad,a9993e364706816aba3e25717850c26c9cd0d89d,true",
  },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
