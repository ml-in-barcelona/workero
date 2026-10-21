open Helpers

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

let () =
  Alcotest.run "workero.method"
    [
      ( "method",
        [
          Alcotest.test_case "round trip" `Quick test_method_round_trip;
          Alcotest.test_case "names" `Quick test_method_names;
        ] );
    ]
