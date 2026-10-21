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

let test_url_unsupported () =
  Alcotest.(check bool)
    "underscore host" true
    (Workero.URL.of_string "http://a_b.test/" = None);
  Alcotest.(check bool)
    "userinfo" true
    (Workero.URL.of_string "http://user:pw@a.test/" = None)

let () =
  Alcotest.run "workero.url"
    [
      ( "url",
        [
          Alcotest.test_case "parts" `Quick test_url_parts;
          Alcotest.test_case "default port" `Quick test_url_default_port;
          Alcotest.test_case "query" `Quick test_url_query;
          Alcotest.test_case "rejects" `Quick test_url_rejects;
          Alcotest.test_case "unsupported" `Quick test_url_unsupported;
        ] );
    ]
