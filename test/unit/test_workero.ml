let url_of s =
  match Workero.URL.of_string s with
  | Some u -> u
  | None -> Alcotest.failf "not a URL: %s" s

let test_url_parts () =
  let u = url_of "https://example.com:8443/a/b?x=1&y=2#frag" in
  Alcotest.(check string) "scheme" "https" (Workero.URL.scheme u);
  Alcotest.(check string) "host" "example.com" (Workero.URL.host u);
  Alcotest.(check int) "port" 8443 (Workero.URL.port u);
  Alcotest.(check string) "path" "/a/b" (Workero.URL.path u)

let test_url_default_port () =
  Alcotest.(check int) "http" 80 (Workero.URL.port (url_of "http://a.test/"));
  Alcotest.(check int) "https" 443 (Workero.URL.port (url_of "https://a.test/"))

let test_url_query () =
  let u = url_of "http://a.test/?k=1&k=2&q=a+b%20c" in
  Alcotest.(check (option string)) "first" (Some "1") (Workero.URL.query u "k");
  Alcotest.(check (list string))
    "all" [ "1"; "2" ]
    (Workero.URL.query_all u "k");
  Alcotest.(check (option string))
    "decoded" (Some "a b c") (Workero.URL.query u "q");
  Alcotest.(check (option string)) "missing" None (Workero.URL.query u "z")

let test_url_rejects () =
  Alcotest.(check bool) "not a URL" true (Workero.URL.of_string "nope" = None);
  Alcotest.(check bool) "ftp" true (Workero.URL.of_string "ftp://a.test/" = None)

let js_global name = Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global name

let js_new name args =
  Js_of_ocaml.Js.Unsafe.new_obj (js_global name) (Array.of_list args)

let inject = Js_of_ocaml.Js.Unsafe.inject
let jstr s = inject (Js_of_ocaml.Js.string s)
let obj = Js_of_ocaml.Js.Unsafe.obj
let js_eval src = Js_of_ocaml.Js.Unsafe.eval_string src

let request ?(init = []) url =
  Workero.Request.of_js
    (js_new "Request" [ jstr url; obj (Array.of_list init) ])

let method_t =
  Alcotest.testable
    (fun ppf m -> Format.pp_print_string ppf (Workero.Method.to_string m))
    ( = )

let test_method_round_trip () =
  let open Workero.Method in
  List.iter
    (fun m -> Alcotest.check method_t (to_string m) m (of_string (to_string m)))
    [ GET; HEAD; POST; PUT; DELETE; PATCH; OPTIONS; Other "PURGE" ]

let test_method_names () =
  let open Workero.Method in
  Alcotest.(check string) "post" "POST" (to_string POST);
  Alcotest.check method_t "custom" (Other "PURGE") (of_string "PURGE");
  Alcotest.check method_t "case-sensitive" (Other "get") (of_string "get")

let test_request_method () =
  let req =
    request
      ~init:[ ("method", jstr "PATCH"); ("body", jstr "x") ]
      "http://a.test/"
  in
  Alcotest.check method_t "method" Workero.Method.PATCH
    (Workero.Request.method_ req);
  Alcotest.check method_t "default" Workero.Method.GET
    (Workero.Request.method_ (request "http://a.test/"))

let test_request_headers () =
  let headers = obj [| ("X-B", jstr "2"); ("x-a", jstr "1") |] in
  let req = request ~init:[ ("headers", headers) ] "http://a.test/" in
  Alcotest.(check (option string))
    "header" (Some "2")
    (Workero.Request.header req "x-b");
  Alcotest.(check (option string))
    "missing" None
    (Workero.Request.header req "x-c");
  Alcotest.(check (list (pair string string)))
    "headers"
    [ ("x-a", "1"); ("x-b", "2") ]
    (Workero.Request.headers req)

let test_request_cf () =
  let open Workero in
  let absent = Request.cf (request "http://a.test/") in
  Alcotest.(check (option string)) "no country" None (Cf.country absent);
  Alcotest.(check (option int)) "no asn" None (Cf.asn absent);
  let cf =
    obj [| ("country", jstr "ES"); ("colo", jstr "BCN"); ("asn", inject 1234) |]
  in
  let req = Request.of_js (obj [| ("cf", cf) |]) in
  let cf = Request.cf req in
  Alcotest.(check (option string)) "country" (Some "ES") (Cf.country cf);
  Alcotest.(check (option string)) "colo" (Some "BCN") (Cf.colo cf);
  Alcotest.(check (option int)) "asn" (Some 1234) (Cf.asn cf);
  Alcotest.(check (option string)) "city" None (Cf.city cf)

let test_response_text () =
  let open Workero.Response in
  let r = text ~status:201 ~headers:[ ("x-a", "1"); ("x-a", "2") ] "hi" in
  Alcotest.(check int) "status" 201 (status r);
  Alcotest.(check (option string)) "repeated" (Some "1, 2") (header r "x-a");
  Alcotest.(check (option string))
    "content-type" (Some "text/plain;charset=UTF-8") (header r "content-type");
  Alcotest.(check int) "default status" 200 (status (text "x"))

let test_response_html () =
  let open Workero.Response in
  Alcotest.(check (option string))
    "default" (Some "text/html; charset=utf-8")
    (header (html "<p>") "content-type");
  let given =
    html ~headers:[ ("Content-Type", "text/html; charset=latin1") ] "<p>"
  in
  Alcotest.(check (list (pair string string)))
    "given wins"
    [ ("content-type", "text/html; charset=latin1") ]
    (headers given)

let test_response_make () =
  let open Workero.Response in
  let r = make ~status:202 "\000\255" in
  Alcotest.(check int) "status" 202 (status r);
  Alcotest.(check (option string))
    "no content-type" None (header r "content-type")

let test_response_redirect () =
  let open Workero.Response in
  let r = redirect "http://a.test/x" in
  Alcotest.(check int) "default" 302 (status r);
  Alcotest.(check (option string))
    "location" (Some "http://a.test/x") (header r "location");
  Alcotest.(check int)
    "301" 301
    (status (redirect ~status:301 "http://a.test/"));
  Alcotest.check_raises "bad status"
    (Invalid_argument "Workero.Response.redirect: status 200") (fun () ->
      ignore (redirect ~status:200 "http://a.test/"))

let test_response_null_body_status () =
  let open Workero.Response in
  List.iter
    (fun code ->
      Alcotest.(check int)
        (string_of_int code) code
        (status (text ~status:code "")))
    [ 204; 205; 304 ];
  Alcotest.(check int) "make" 204 (status (make ~status:204 ""))

let test_fetch_body_needs_a_method_with_body () =
  List.iter
    (fun m ->
      Alcotest.check_raises (Workero.Method.to_string m)
        (Invalid_argument "Workero.fetch: a GET or HEAD request has no body")
        (fun () -> ignore (Workero.fetch ~method_:m ~body:"x" "http://a.test/")))
    [ Workero.Method.GET; HEAD ];
  Alcotest.check_raises "default method"
    (Invalid_argument "Workero.fetch: a GET or HEAD request has no body")
    (fun () -> ignore (Workero.fetch ~body:"x" "http://a.test/"))

let test_url_unsupported () =
  Alcotest.(check bool)
    "underscore host" true
    (Workero.URL.of_string "http://a_b.test/" = None);
  Alcotest.(check bool)
    "userinfo" true
    (Workero.URL.of_string "http://user:pw@a.test/" = None)

let test_env_var () =
  let env = Workero.Env.of_js (obj [| ("A", jstr "x"); ("B", inject 1) |]) in
  Alcotest.(check (option string)) "string" (Some "x") (Workero.Env.var env "A");
  Alcotest.(check (option string)) "not a string" None (Workero.Env.var env "B");
  Alcotest.(check (option string)) "missing" None (Workero.Env.var env "C")

let test_scheduled () =
  let c =
    Workero.Scheduled.of_js
      (obj [| ("cron", jstr "*/5 * * * *"); ("scheduledTime", inject 1.7e12) |])
  in
  Alcotest.(check string) "cron" "*/5 * * * *" (Workero.Scheduled.cron c);
  Alcotest.(check (float 0.)) "time" 1.7e12 (Workero.Scheduled.scheduled_time c);
  let empty = Workero.Scheduled.of_js (obj [||]) in
  Alcotest.(check string) "no cron" "" (Workero.Scheduled.cron empty);
  Alcotest.(check (float 0.))
    "no time" 0.
    (Workero.Scheduled.scheduled_time empty)

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

let value =
  Alcotest.testable
    (fun ppf (v : Workero.Sql_value.t) ->
      match v with
      | Null -> Format.pp_print_string ppf "Null"
      | Int n -> Format.fprintf ppf "Int %Ld" n
      | Float f -> Format.fprintf ppf "Float %g" f
      | Text s -> Format.fprintf ppf "Text %S" s
      | Blob s -> Format.fprintf ppf "Blob %S" s)
    ( = )

let test_sql_value_of_js () =
  let open Workero.Sql_value in
  List.iter
    (fun (src, expected) ->
      Alcotest.check value src expected (of_js (js_eval src)))
    [
      ("null", Null);
      ("undefined", Null);
      ("42", Int 42L);
      ("-5", Int (-5L));
      ("3000000000", Int 3_000_000_000L);
      ("9007199254740992", Int 9_007_199_254_740_992L);
      ("1.5", Float 1.5);
      ("1e300", Float 1e300);
      ("'h\\u00e9'", Text "h\xc3\xa9");
      ("9223372036854775807n", Int Int64.max_int);
      ("-9223372036854775808n", Int Int64.min_int);
      ("new Uint8Array([0, 255, 10]).buffer", Blob "\000\255\n");
      ("new Uint8Array([0, 255, 10])", Blob "\000\255\n");
      ("[0, 255, 10]", Blob "\000\255\n");
    ]

let test_sql_value_to_js () =
  let open Workero.Sql_value in
  List.iter
    (fun v -> Alcotest.check value "round trip" v (of_js (to_js v)))
    [
      Null;
      Int 3_000_000_000L;
      Int (-9_007_199_254_740_992L);
      Float 2.5;
      Text "x";
      Blob "\255\000\128";
    ];
  Alcotest.check_raises "beyond 2^53"
    (Invalid_argument "Workero.Sql_value.to_js: 9007199254740993 is beyond 2^53")
    (fun () -> ignore (to_js (Int 9_007_199_254_740_993L)))

let test_sql_value_rejects () =
  let open Workero.Sql_value in
  List.iter
    (fun (src, message) ->
      Alcotest.check_raises src (Invalid_argument message) (fun () ->
          ignore (of_js (js_eval src))))
    [
      ("true", "Workero.Sql_value.of_js: unsupported JS value of type boolean");
      ("({})", "Workero.Sql_value.of_js: unsupported JS value of type object");
      ( "Symbol('s')",
        "Workero.Sql_value.of_js: unsupported JS value of type symbol" );
      ( "9223372036854775808n",
        "Workero.Sql_value.of_js: 9223372036854775808 is outside the int64 \
         range" );
      ( "-9223372036854775809n",
        "Workero.Sql_value.of_js: -9223372036854775809 is outside the int64 \
         range" );
    ];
  Alcotest.check value "Int16Array bytes" (Blob "\001\000\002\000")
    (of_js (js_eval "new Int16Array([1, 2])"));
  Alcotest.check value "DataView bytes" (Blob "\007")
    (of_js (js_eval "new DataView(new Uint8Array([7]).buffer)"))

let test_decode () =
  let open Workero.Decode in
  let v = js_eval "({ a: [1, 2, null], b: 'x', c: true, d: 1.5, e: null })" in
  Alcotest.(check (list (option int)))
    "list of option" [ Some 1; Some 2; None ]
    (field "a" (list (option int)) v);
  Alcotest.(check string) "string" "x" (field "b" string v);
  Alcotest.(check bool) "bool" true (field "c" bool v);
  Alcotest.(check (float 0.)) "float" 1.5 (field "d" float v);
  Alcotest.(check (option string)) "null" None (field "e" (option string) v);
  Alcotest.(check (option string)) "absent" None (field "z" (option string) v);
  Alcotest.(check string)
    "bytes" "\000\255"
    (bytes (js_eval "new Uint8Array([0, 255])"));
  let check_raises decode src message =
    Alcotest.check_raises src (Invalid_argument message) (fun () ->
        Stdlib.ignore (decode (js_eval src)))
  in
  check_raises
    (fun v -> Stdlib.ignore (string v))
    "5" "Workero.Decode: expected string, got number";
  check_raises
    (fun v -> Stdlib.ignore (int v))
    "'x'" "Workero.Decode: expected number, got string";
  check_raises
    (fun v -> Stdlib.ignore (int v))
    "1.5" "Workero.Decode: expected an integer, got a fraction";
  check_raises
    (fun v -> Stdlib.ignore (bool v))
    "null" "Workero.Decode: expected boolean, got null or undefined";
  check_raises
    (fun v -> Stdlib.ignore (list string v))
    "({})" "Workero.Decode: expected array, got object";
  check_raises
    (fun v -> Stdlib.ignore (bytes v))
    "'x'" "Workero.Decode: expected bytes, got string"

let () =
  Alcotest.run "workero"
    [
      ( "url",
        [
          Alcotest.test_case "parts" `Quick test_url_parts;
          Alcotest.test_case "default port" `Quick test_url_default_port;
          Alcotest.test_case "query" `Quick test_url_query;
          Alcotest.test_case "rejects" `Quick test_url_rejects;
          Alcotest.test_case "unsupported" `Quick test_url_unsupported;
        ] );
      ( "method",
        [
          Alcotest.test_case "round trip" `Quick test_method_round_trip;
          Alcotest.test_case "names" `Quick test_method_names;
        ] );
      ( "request",
        [
          Alcotest.test_case "method" `Quick test_request_method;
          Alcotest.test_case "headers" `Quick test_request_headers;
          Alcotest.test_case "cf" `Quick test_request_cf;
        ] );
      ( "response",
        [
          Alcotest.test_case "text" `Quick test_response_text;
          Alcotest.test_case "html" `Quick test_response_html;
          Alcotest.test_case "make" `Quick test_response_make;
          Alcotest.test_case "redirect" `Quick test_response_redirect;
          Alcotest.test_case "null body status" `Quick
            test_response_null_body_status;
        ] );
      ( "fetch",
        [
          Alcotest.test_case "body needs a method with body" `Quick
            test_fetch_body_needs_a_method_with_body;
        ] );
      ("bindings", [ Alcotest.test_case "missing" `Quick test_binding_missing ]);
      ( "sql_value",
        [
          Alcotest.test_case "of_js" `Quick test_sql_value_of_js;
          Alcotest.test_case "to_js" `Quick test_sql_value_to_js;
        ] );
      ( "binding",
        [ Alcotest.test_case "sql_value rejects" `Quick test_sql_value_rejects ]
      );
      ("decode", [ Alcotest.test_case "decoders" `Quick test_decode ]);
      ("env", [ Alcotest.test_case "var" `Quick test_env_var ]);
      ("scheduled", [ Alcotest.test_case "fields" `Quick test_scheduled ]);
    ]
