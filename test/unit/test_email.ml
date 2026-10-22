open Helpers
module Email = Workero.Email

let message =
  Email.of_js
    (js_eval
       "({ from: 'a@example.org', to: 'b@example.com', rawSize: 42,\n\
       \  headers: new Headers([['Subject', 'Hi'], ['X-Tag', 'one'], ['X-Tag', \
        'two']]),\n\
       \  rejected: null,\n\
       \  setReject(reason) { this.rejected = reason; } })")

let test_accessors () =
  Alcotest.(check string) "from" "a@example.org" (Email.from message);
  Alcotest.(check string) "to" "b@example.com" (Email.to_ message);
  Alcotest.(check int) "raw size" 42 (Email.raw_size message)

let test_headers () =
  Alcotest.(check (option string))
    "case" (Some "Hi")
    (Email.header message "SUBJECT");
  Alcotest.(check (option string)) "missing" None (Email.header message "nope");
  Alcotest.(check (list string))
    "joined" [ "one, two" ]
    (Email.header_all message "x-tag");
  Alcotest.(check (list (pair string string)))
    "all"
    [ ("subject", "Hi"); ("x-tag", "one, two") ]
    (Email.headers message)

let test_set_reject () =
  Email.set_reject message "no thanks";
  let rejected =
    Js_of_ocaml.Js.Unsafe.get (Email.to_js message) "rejected"
    |> Js_of_ocaml.Js.to_string
  in
  Alcotest.(check string) "reason" "no thanks" rejected

let test_missing_fields () =
  let empty = Email.of_js (obj [||]) in
  match Email.from empty with
  | _ -> Alcotest.fail "no exception"
  | exception Invalid_argument _ -> ()

let () =
  Alcotest.run "workero.email"
    [
      ( "email",
        [
          Alcotest.test_case "accessors" `Quick test_accessors;
          Alcotest.test_case "headers" `Quick test_headers;
          Alcotest.test_case "set_reject" `Quick test_set_reject;
          Alcotest.test_case "missing fields" `Quick test_missing_fields;
        ] );
    ]
