open Helpers
module W = Workero.Websocket

let test_js_round_trip () =
  let v = inject (obj [||]) in
  Alcotest.(check bool) "same value" true (W.to_js (W.of_js v) == v)

let describe = function
  | W.Message (Text s) -> "text " ^ s
  | Message (Binary b) -> Printf.sprintf "binary %d" (String.length b)
  | Close { code; reason; was_clean } ->
      Printf.sprintf "close %d %s %b" code reason was_clean
  | Failed s -> "failed " ^ s

let test_events () =
  Alcotest.(check (list string))
    "constructors"
    [ "text a"; "binary 2"; "close 1000 bye true"; "failed x" ]
    (List.map describe
       [
         Message (Text "a");
         Message (Binary "\000\255");
         Close { code = 1000; reason = "bye"; was_clean = true };
         Failed "x";
       ])

let () =
  Alcotest.run "workero.websocket"
    [
      ( "websocket",
        [
          Alcotest.test_case "js round trip" `Quick test_js_round_trip;
          Alcotest.test_case "events" `Quick test_events;
        ] );
    ]
