open Helpers

let test_pipe () =
  let _writer, stream = Workero.Stream.pipe () in
  Alcotest.(check bool)
    "readable stream" true
    (js_instance_of (Workero.Stream.to_js stream) "ReadableStream")

let test_reader_locks () =
  let _writer, stream = Workero.Stream.pipe () in
  let _reader = Workero.Stream.reader stream in
  raises_js_error "second reader" (fun () -> Workero.Stream.reader stream)

let test_reader_release () =
  let _writer, stream = Workero.Stream.pipe () in
  Workero.Stream.Reader.release (Workero.Stream.reader stream);
  ignore (Workero.Stream.reader stream)

let test_js_round_trip () =
  let v = js_new "ReadableStream" [] in
  Alcotest.(check bool)
    "same value" true
    (Workero.Stream.to_js (Workero.Stream.of_js v) == v)

let () =
  Alcotest.run "workero.stream"
    [
      ( "stream",
        [
          Alcotest.test_case "pipe" `Quick test_pipe;
          Alcotest.test_case "reader locks the stream" `Quick test_reader_locks;
          Alcotest.test_case "release unlocks the stream" `Quick
            test_reader_release;
          Alcotest.test_case "js round trip" `Quick test_js_round_trip;
        ] );
    ]
