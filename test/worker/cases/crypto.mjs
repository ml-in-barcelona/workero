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
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
