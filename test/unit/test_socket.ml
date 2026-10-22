let invalid name message f =
  Alcotest.check_raises name (Invalid_argument message) (fun () ->
      ignore (f ()))

let test_arguments () =
  invalid "empty host" "Workero.Socket.connect: host is empty" (fun () ->
      Workero.Socket.connect ~host:"" ~port:80 ());
  invalid "port 0" "Workero.Socket.connect: port 0 is outside 1 to 65535"
    (fun () -> Workero.Socket.connect ~host:"h" ~port:0 ());
  invalid "port 65536"
    "Workero.Socket.connect: port 65536 is outside 1 to 65535" (fun () ->
      Workero.Socket.connect ~host:"h" ~port:65536 ())

let test_outside_a_worker () =
  Alcotest.check_raises "no cloudflare:sockets"
    (Failure
       "Workero.Socket.connect: cloudflare:sockets is not available here; run \
        the program as a Worker built by workero build") (fun () ->
      ignore (Workero.Socket.connect ~host:"h" ~port:80 ()))

let () =
  Alcotest.run "workero.socket"
    [
      ( "socket",
        [
          Alcotest.test_case "arguments" `Quick test_arguments;
          Alcotest.test_case "outside a worker" `Quick test_outside_a_worker;
        ] );
    ]
