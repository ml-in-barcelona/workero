open Helpers

let js_number src =
  Js_of_ocaml.Js.float_of_number (Js_of_ocaml.Js.Unsafe.coerce (js_eval src))

let raises_invalid name f =
  match f () with
  | _ -> Alcotest.failf "%s: no exception" name
  | exception Invalid_argument _ -> ()

let test_now () =
  let before = js_number "Date.now()" in
  let t = Workero.Date.now () in
  let after = js_number "Date.now()" in
  Alcotest.(check bool) "within clock" true (before <= t && t <= after);
  Alcotest.(check bool) "monotonic" true (Workero.Date.now () >= t)

let test_iso () =
  Alcotest.(check string)
    "epoch" "1970-01-01T00:00:00.000Z"
    (Workero.Date.to_iso_string 0.);
  Alcotest.(check string)
    "known" "2023-11-14T22:13:20.123Z"
    (Workero.Date.to_iso_string 1700000000123.)

let test_iso_invalid () =
  raises_invalid "nan" (fun () -> Workero.Date.to_iso_string nan);
  raises_invalid "infinity" (fun () -> Workero.Date.to_iso_string infinity);
  raises_invalid "out of range" (fun () -> Workero.Date.to_iso_string 8.65e15)

let test_uuid () =
  let re =
    js_eval
      "/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/"
  in
  let matches s =
    Js_of_ocaml.Js.to_bool
      (Js_of_ocaml.Js.Unsafe.coerce
         (Js_of_ocaml.Js.Unsafe.meth_call re "test" [| jstr s |]))
  in
  let a = Workero.Crypto.random_uuid () and b = Workero.Crypto.random_uuid () in
  Alcotest.(check bool) "a v4" true (matches a);
  Alcotest.(check bool) "b v4" true (matches b);
  Alcotest.(check bool) "differ" true (a <> b)

let test_bytes () =
  List.iter
    (fun n ->
      Alcotest.(check int)
        (string_of_int n) n
        (String.length (Workero.Crypto.random_bytes n)))
    [ 0; 16; 65536 ];
  Alcotest.(check string) "empty" "" (Workero.Crypto.random_bytes 0);
  Alcotest.(check bool)
    "distinct" true
    (Workero.Crypto.random_bytes 16 <> Workero.Crypto.random_bytes 16);
  raises_invalid "negative" (fun () -> Workero.Crypto.random_bytes (-1));
  raises_invalid "too many" (fun () -> Workero.Crypto.random_bytes 65537)

let test_console () =
  ignore
    (js_eval
       "globalThis.__saved = {}; globalThis.__seen = [];\n\
        for (const l of ['log','info','warn','error','debug']) {\n\
       \  globalThis.__saved[l] = console[l];\n\
       \  console[l] = (m) => globalThis.__seen.push(l + ':' + m);\n\
        }");
  Workero.Console.log "a";
  Workero.Console.info "b";
  Workero.Console.warn "c";
  Workero.Console.error "d";
  Workero.Console.debug "e";
  let seen =
    js_eval
      "(() => { for (const l of ['log','info','warn','error','debug']) \
       console[l] = globalThis.__saved[l]; return globalThis.__seen.join(',') \
       })()"
  in
  Alcotest.(check string)
    "calls" "log:a,info:b,warn:c,error:d,debug:e"
    (Js_of_ocaml.Js.to_string (Js_of_ocaml.Js.Unsafe.coerce seen))

let test_timers () =
  let t = Workero.Timer.set_timeout (fun () -> ()) 10_000 in
  Workero.Timer.clear_timeout t;
  Workero.Timer.clear_timeout t;
  let i = Workero.Timer.set_interval (fun () -> ()) 10_000 in
  Workero.Timer.clear_interval i

let () =
  Alcotest.run "workero.globals"
    [
      ( "date",
        [
          Alcotest.test_case "now" `Quick test_now;
          Alcotest.test_case "iso" `Quick test_iso;
          Alcotest.test_case "iso invalid" `Quick test_iso_invalid;
        ] );
      ( "crypto",
        [
          Alcotest.test_case "uuid" `Quick test_uuid;
          Alcotest.test_case "bytes" `Quick test_bytes;
        ] );
      ("console", [ Alcotest.test_case "levels" `Quick test_console ]);
      ("timer", [ Alcotest.test_case "set and clear" `Quick test_timers ]);
    ]
