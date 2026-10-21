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

let test_url_underscore_host () =
  let u = url_of "http://my_host:8080/p/x" in
  Alcotest.(check string) "host" "my_host" (Workero.URL.host u);
  Alcotest.(check int) "port" 8080 (Workero.URL.port u);
  Alcotest.(check string) "path" "/p/x" (Workero.URL.path u)

let test_url_userinfo () =
  let u = url_of "http://user:pw@a.test/x" in
  Alcotest.(check string) "host" "a.test" (Workero.URL.host u);
  Alcotest.(check string) "path" "/x" (Workero.URL.path u)

let path_table =
  [
    ("http://a.test", "/");
    ("http://a.test/", "/");
    ("http://a.test/a%20b", "/a b");
    ("http://a.test/a+b", "/a+b");
    ("http://a.test/%C3%A9", "/\xc3\xa9");
    ("http://a.test/a?x=1#f", "/a");
    ("http://a.test/%zz", "/%zz");
  ]

let test_url_path_table () =
  List.iter
    (fun (input, expected) ->
      Alcotest.(check string) input expected (Workero.URL.path (url_of input)))
    path_table

let args_table =
  [
    ("http://a.test/", []);
    ("http://a.test/?", []);
    ("http://a.test/?a=1", [ ("a", "1") ]);
    ("http://a.test/?a=1&a=2&b=3", [ ("a", "1"); ("a", "2"); ("b", "3") ]);
    ("http://a.test/?q=a+b%20c", [ ("q", "a b c") ]);
    ("http://a.test/?k=%C3%A9", [ ("k", "\xc3\xa9") ]);
    ("http://a.test/?a=1#f", [ ("a", "1") ]);
    ("http://a.test/?a=%zz", [ ("a", "%zz") ]);
  ]

let test_url_args_table () =
  List.iter
    (fun (input, expected) ->
      Alcotest.(check (list (pair string string)))
        input expected
        (Workero.URL.query_args (url_of input)))
    args_table

let test_url_key_without_value () =
  let u = url_of "http://a.test/?a&b=2" in
  Alcotest.(check (option string)) "a" (Some "") (Workero.URL.query u "a");
  Alcotest.(check (option string)) "b" (Some "2") (Workero.URL.query u "b")

let test_url_to_string () =
  Alcotest.(check string)
    "round trip" "http://a.test/p?x=1"
    (Workero.URL.to_string (url_of "http://a.test/p?x=1"))

let () =
  Alcotest.run "workero.url"
    [
      ( "url",
        [
          Alcotest.test_case "parts" `Quick test_url_parts;
          Alcotest.test_case "default port" `Quick test_url_default_port;
          Alcotest.test_case "query" `Quick test_url_query;
          Alcotest.test_case "rejects" `Quick test_url_rejects;
          Alcotest.test_case "underscore host" `Quick test_url_underscore_host;
          Alcotest.test_case "userinfo" `Quick test_url_userinfo;
          Alcotest.test_case "path table" `Quick test_url_path_table;
          Alcotest.test_case "args table" `Quick test_url_args_table;
          Alcotest.test_case "key without value" `Quick
            test_url_key_without_value;
          Alcotest.test_case "to_string" `Quick test_url_to_string;
        ] );
    ]
