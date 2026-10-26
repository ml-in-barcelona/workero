open Workero

let host = "tcp.test"
let sleep ms = Promise.await (Timer.sleep ms)

let connect ?secure_transport ?allow_half_open () =
  let socket =
    Socket.connect ?secure_transport ?allow_half_open ~host ~port:7 ()
  in
  ignore (Socket.opened socket);
  socket

let read_all reader total =
  let buf = Buffer.create total in
  while Buffer.length buf < total do
    match Stream.Reader.read reader with
    | Some chunk -> Buffer.add_string buf chunk
    | None -> failwith "unexpected end of stream"
  done;
  Buffer.contents buf

let error_text f =
  match f () with
  | _ -> "no error"
  | exception Js_error e -> "Js_error: " ^ Promise.error_to_string e
  | exception Invalid_argument m -> "Invalid_argument: " ^ m

let echo () =
  let socket = connect () in
  let reader = Socket.reader socket in
  let writer = Socket.writer socket in
  Stream.Writer.write writer "hello";
  let echoed = read_all reader 5 in
  Stream.Writer.close writer;
  let eof = Stream.Reader.read reader = None in
  Socket.closed socket;
  Printf.sprintf "echo=%s eof=%b" echoed eof

let bytes () =
  let socket = connect () in
  let reader = Socket.reader socket in
  let writer = Socket.writer socket in
  let data = String.init 256 Char.chr in
  Stream.Writer.write writer data;
  let echoed = read_all reader 256 in
  Socket.close socket;
  Printf.sprintf "same=%b" (echoed = data)

let large () =
  let socket = connect () in
  let reader = Socket.reader socket in
  let writer = Socket.writer socket in
  let chunk = String.init 4096 (fun i -> Char.chr (i * 7 mod 256)) in
  let same = ref true in
  let size = ref 0 in
  for _ = 1 to 16 do
    Stream.Writer.write writer chunk;
    let echoed = read_all reader 4096 in
    size := !size + String.length echoed;
    same := !same && echoed = chunk
  done;
  Socket.close socket;
  Printf.sprintf "size=%d same=%b" !size !same

let server_close ~half_open =
  let socket = connect ~allow_half_open:half_open () in
  let reader = Socket.reader socket in
  let writer = Socket.writer socket in
  Stream.Writer.write writer "bye";
  let eof = Stream.Reader.read reader = None in
  sleep 50;
  let late =
    match Stream.Writer.write writer "late" with
    | () -> "ok"
    | exception Js_error _ -> "refused"
  in
  Printf.sprintf "eof=%b late=%s" eof late

let close () =
  let socket = connect () in
  Socket.close socket;
  Socket.closed socket;
  "closed"

let locked () =
  let socket = connect () in
  ignore (Socket.reader socket);
  ignore (Socket.writer socket);
  Printf.sprintf "reader=%s writer=%s"
    (error_text (fun () -> Socket.reader socket))
    (error_text (fun () -> Socket.writer socket))

let release () =
  let socket = connect () in
  let reader = Socket.reader socket in
  let writer = Socket.writer socket in
  Stream.Reader.release reader;
  Stream.Writer.release writer;
  let writer = Socket.writer socket in
  let reader = Socket.reader socket in
  Stream.Writer.write writer "again";
  let echoed = read_all reader 5 in
  Socket.close socket;
  "echo=" ^ echoed

let invalid () =
  String.concat "\n"
    [
      error_text (fun () -> Socket.connect ~host:"" ~port:80 ());
      error_text (fun () -> Socket.connect ~host ~port:0 ());
      error_text (fun () -> Socket.connect ~host ~port:65536 ());
    ]

let info () =
  let socket = Socket.connect ~host ~port:7 () in
  let { Socket.remote_address; local_address } = Socket.opened socket in
  let show = function Some a -> "some:" ^ a | None -> "none" in
  Socket.close socket;
  Printf.sprintf "remote=%s local=%s" (show remote_address) (show local_address)

let upgraded () =
  let plain = connect () in
  let starttls = connect ~secure_transport:Starttls () in
  let before = Socket.upgraded starttls in
  let secure = Socket.start_tls starttls in
  Printf.sprintf "plain=%b before=%b original=%b secure=%b"
    (Socket.upgraded plain) before (Socket.upgraded starttls)
    (Socket.upgraded secure)

let handle req _env _ctx =
  let url = Request.url req in
  let text s = Some (Response.text s) in
  match URL.path url with
  | "/socket/echo" -> text (echo ())
  | "/socket/bytes" -> text (bytes ())
  | "/socket/large" -> text (large ())
  | "/socket/server-close" ->
      text (server_close ~half_open:(URL.query url "half" = Some "true"))
  | "/socket/close" -> text (close ())
  | "/socket/locked" -> text (locked ())
  | "/socket/release" -> text (release ())
  | "/socket/info" -> text (info ())
  | "/socket/upgraded" -> text (upgraded ())
  | "/socket/invalid" -> text (invalid ())
  | "/socket/tls-on" ->
      text
        (error_text (fun () ->
             Socket.opened
               (Socket.connect ~secure_transport:On ~host ~port:7 ())))
  | "/socket/start-tls" ->
      let secure_transport =
        if URL.query url "mode" = Some "starttls" then Socket.Starttls
        else Socket.Off
      in
      text
        (error_text (fun () ->
             let socket = connect ~secure_transport () in
             Socket.opened (Socket.start_tls socket)))
  | _ -> None
