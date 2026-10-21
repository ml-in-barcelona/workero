open Helpers
module F = Workero.Form_data

let append form name v =
  ignore (Js_of_ocaml.Js.Unsafe.meth_call form "append" [| jstr name; v |])

let sample () =
  let form = js_new "FormData" [] in
  append form "title" (jstr "one");
  append form "title" (jstr "two");
  append form "file"
    (inject
       (js_new "File"
          [
            inject (Js_of_ocaml.Js.array [| jstr "abc" |]);
            jstr "a.txt";
            inject (obj [| ("type", jstr "text/plain") |]);
          ]));
  F.of_js form

let text_t = Alcotest.(option string)
let text = function Some (F.Text s) -> Some s | _ -> None

let test_get () =
  let form = sample () in
  Alcotest.check text_t "first" (Some "one") (text (F.get form "title"));
  Alcotest.check text_t "missing" None (text (F.get form "nope"));
  Alcotest.(check bool) "missing is None" true (F.get form "nope" = None)

let test_get_all () =
  let all = F.get_all (sample ()) "title" in
  Alcotest.(check (list (option string)))
    "both, in order" [ Some "one"; Some "two" ]
    (List.map (fun v -> text (Some v)) all);
  Alcotest.(check int) "none" 0 (List.length (F.get_all (sample ()) "nope"))

let test_to_list () =
  Alcotest.(check (list string))
    "names in order"
    [ "title"; "title"; "file" ]
    (List.map fst (F.to_list (sample ())))

let test_file () =
  match F.get (sample ()) "file" with
  | Some (F.File f) ->
      Alcotest.(check string) "name" "a.txt" (F.file_name f);
      Alcotest.(check string) "type" "text/plain" (F.file_type f);
      Alcotest.(check int) "size" 3 (F.file_size f)
  | _ -> Alcotest.fail "expected a file"

let test_js_round_trip () =
  let v = js_new "FormData" [] in
  Alcotest.(check bool) "same value" true (F.to_js (F.of_js v) == v)

let () =
  Alcotest.run "workero.form_data"
    [
      ( "form_data",
        [
          Alcotest.test_case "get" `Quick test_get;
          Alcotest.test_case "get_all" `Quick test_get_all;
          Alcotest.test_case "to_list" `Quick test_to_list;
          Alcotest.test_case "file fields" `Quick test_file;
          Alcotest.test_case "js round trip" `Quick test_js_round_trip;
        ] );
    ]
