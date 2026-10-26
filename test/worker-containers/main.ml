open Workero
module D = Durable_object

let page =
  "mkdir -p /www; echo hello-from-container > /www/index.html; exec httpd -f \
   -p 8080 -h /www"

let trap = "trap 'exit 0' TERM; sleep 300 & wait"
let ok = Response.text
let intercepted_host = "10.1.2.3"

let fetch_page =
  Printf.sprintf
    "mkdir -p /www; until wget -q -O /www/out http://%s/hi; do sleep 1; done; \
     exec httpd -f -p 8080 -h /www"
    intercepted_host

let rec get_body ?(path = "index.html") port attempts =
  let retry reason =
    if attempts = 0 then failwith ("the container never answered: " ^ reason)
    else (
      Promise.await (Timer.sleep 500);
      get_body ~path port (attempts - 1))
  in
  match Fetcher.fetch port ("http://container/" ^ path) with
  | res when Response.status res = 200 -> Response.body_text res
  | res -> retry (Printf.sprintf "status %d" (Response.status res))
  | exception Js_error e -> retry (Promise.error_to_string e)

let read_all reader =
  let buf = Buffer.create 256 in
  let rec go () =
    match Stream.Reader.read reader with
    | Some chunk ->
        Buffer.add_string buf chunk;
        go ()
    | None -> Buffer.contents buf
  in
  go ()

let split_response response =
  let rec find i =
    if i + 4 > String.length response then None
    else if String.sub response i 4 = "\r\n\r\n" then Some i
    else find (i + 1)
  in
  Option.map
    (fun i ->
      ( List.hd (String.split_on_char '\r' response),
        String.sub response (i + 4) (String.length response - i - 4) ))
    (find 0)

let rec tcp_response container attempts =
  let retry reason =
    if attempts = 0 then failwith ("tcp never answered: " ^ reason)
    else (
      Promise.await (Timer.sleep 500);
      tcp_response container (attempts - 1))
  in
  match
    let socket = D.Container.connect container ~port:8080 in
    Socket.opened socket;
    Stream.Writer.write (Socket.writer socket)
      "GET /index.html HTTP/1.0\r\n\r\n";
    let response = read_all (Socket.reader socket) in
    Socket.close socket;
    response
  with
  | "" -> retry "empty response"
  | response -> response
  | exception Js_error e -> retry (Promise.error_to_string e)

let rec run container ?cwd ?env ?stdin cmd attempts =
  match D.Container.exec ?cwd ?env ?stdin container cmd with
  | process -> process
  | exception Js_error e ->
      if attempts = 0 then
        failwith ("exec never worked: " ^ Promise.error_to_string e)
      else (
        Promise.await (Timer.sleep 500);
        run container ?cwd ?env ?stdin cmd (attempts - 1))

let output container ?cwd ?env cmd =
  let o = D.Container.Process.output (run container ?cwd ?env cmd 40) in
  Printf.sprintf "out=%s|err=%s|exit=%d" o.stdout o.stderr o.exit_code

let sh container script = output container [ "sh"; "-c"; script ]

let sandbox state env =
  let container = Option.get (D.State.container state) in
  let start entrypoint =
    D.Container.start ~entrypoint:[ "sh"; "-c"; entrypoint ] container
  in
  D.make
    ~fetch:(fun req ->
      match Request.path req with
      | "/fetch" ->
          if not (D.Container.running container) then start page;
          ok
            (Printf.sprintf "running=%b|%s"
               (D.Container.running container)
               (get_body (D.Container.get_tcp_port container 8080) 40))
      | "/tcp" -> (
          if not (D.Container.running container) then start page;
          let response = tcp_response container 40 in
          match split_response response with
          | Some (head, body) -> ok (head ^ "|" ^ body)
          | None -> ok ("malformed: " ^ response))
      | "/timeout" ->
          let invalid =
            match D.Container.set_inactivity_timeout container ~ms:0 with
            | () -> "no raise"
            | exception Invalid_argument _ -> "invalid"
          in
          D.Container.set_inactivity_timeout container ~ms:60_000;
          if not (D.Container.running container) then start page;
          ok
            (Printf.sprintf "timeout=set|%s|%s" invalid
               (get_body (D.Container.get_tcp_port container 8080) 40))
      | "/intercept" ->
          D.Container.intercept_outbound_http container intercepted_host
            (Fetcher.of_env env "SELF");
          if not (D.Container.running container) then start fetch_page;
          ok (get_body ~path:"out" (D.Container.get_tcp_port container 8080) 40)
      | "/destroy" ->
          D.Container.destroy container;
          ok (Printf.sprintf "running=%b" (D.Container.running container))
      | "/monitor" ->
          start "sleep 1";
          D.Container.monitor container;
          ok "exited"
      | "/signal" ->
          start trap;
          D.Container.signal container 15;
          D.Container.monitor container;
          ok "stopped"
      | "/destroy-message" -> (
          start "sleep 300";
          D.Container.destroy ~message:"bye" container;
          match D.Container.monitor container with
          | () -> ok "no raise"
          | exception Js_error e -> ok (Promise.error_to_string e))
      | "/exec" ->
          start trap;
          ok
            (output container ~cwd:"/tmp"
               ~env:[ ("GREETING", "hi") ]
               [ "sh"; "-c"; "echo $GREETING:$(pwd); echo oops >&2; exit 3" ])
      | "/exec-stdin" ->
          start trap;
          let p = run container ~stdin:`Pipe [ "cat" ] 40 in
          let writer = Option.get (D.Container.Process.stdin p) in
          Stream.Writer.write writer "ping";
          Stream.Writer.close writer;
          ok (D.Container.Process.output p).stdout
      | "/inspect" -> (
          start trap;
          ignore (output container [ "true" ]);
          match D.Container.inspect container with
          | Some info -> ok ("inspect=some|" ^ string_of_bool (info.image <> ""))
          | None -> ok "inspect=none")
      | "/snapshot" ->
          start trap;
          ignore (sh container "echo saved > /root/state");
          let snapshot = D.Container.snapshot_container container in
          D.Container.destroy container;
          D.Container.start ~entrypoint:[ "sh"; "-c"; trap ]
            ~container_snapshot:snapshot container;
          ok
            (Printf.sprintf "size>0=%b|%s" (snapshot.size > 0)
               (sh container "cat /root/state"))
      | "/snapshot-dir" ->
          start trap;
          ignore (sh container "mkdir -p /data; echo kept > /data/f");
          let snapshot =
            D.Container.snapshot_directory container ~dir:"/data"
          in
          D.Container.destroy container;
          D.Container.start ~entrypoint:[ "sh"; "-c"; trap ]
            ~directory_snapshots:
              [
                { D.Container.Directory_snapshot.snapshot; mount_point = None };
              ]
            container;
          ok (sh container "cat /data/f")
      | _ -> Response.text ~status:`Not_Found "not found")
    ()

let () = D.register "Sandbox" sandbox

let () =
  Workero.serve (fun req env _ctx ->
      match String.split_on_char '/' (Request.path req) with
      | _ when URL.host (Request.url req) = intercepted_host ->
          ok ("intercepted:" ^ Request.path req)
      | [ ""; name; op ] ->
          let ns = D.Namespace.of_env env "SANDBOX" in
          ok
            (Response.body_text
               (Fetcher.fetch
                  (D.Namespace.get_by_name ns name)
                  ("http://do/" ^ op)))
      | _ -> Response.text ~status:`Not_Found "not found")
