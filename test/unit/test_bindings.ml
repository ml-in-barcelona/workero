open Helpers

let test_binding_missing () =
  let kv = js_eval "({ get() {}, put() {}, delete() {}, list() {} })" in
  let env = Workero.Env.of_js (obj [| ("KV", kv) |]) in
  ignore (Workero.KV.of_env env "KV");
  Alcotest.check_raises "kv"
    (Invalid_argument "Workero.KV.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.KV.of_env env "NOPE"));
  Alcotest.check_raises "r2"
    (Invalid_argument "Workero.R2.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.R2.of_env env "NOPE"));
  Alcotest.check_raises "d1"
    (Invalid_argument "Workero.D1.of_env: binding \"NOPE\" not found")
    (fun () -> ignore (Workero.D1.of_env env "NOPE"))

let () =
  Alcotest.run "workero.bindings"
    [
      ("bindings", [ Alcotest.test_case "missing" `Quick test_binding_missing ]);
    ]
