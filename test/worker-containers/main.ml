open Workero
module D = Durable_object

let page =
  "mkdir -p /www; echo hello-from-container > /www/index.html; exec httpd -f \
   -p 8080 -h /www"

let trap = "trap 'exit 0' TERM; sleep 300 & wait"
let ok = Response.text

let rec get_body port attempts =
  let retry reason =
    if attempts = 0 then failwith ("the container never answered: " ^ reason)
    else (
      Promise.await (Timer.sleep 500);
      get_body port (attempts - 1))
  in
  match Fetcher.fetch port "http://container/index.html" with
  | res when Response.status res = 200 -> Response.body_text res
  | res -> retry (Printf.sprintf "status %d" (Response.status res))
  | exception Js_error e -> retry (Promise.error_to_string e)

let sandbox state _env =
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
      | _ -> Response.text ~status:`Not_Found "not found")
    ()

let () = D.register "Sandbox" sandbox

let () =
  Workero.serve (fun req env _ctx ->
      match String.split_on_char '/' (Request.path req) with
      | [ ""; name; op ] ->
          let ns = D.Namespace.of_env env "SANDBOX" in
          ok
            (Response.body_text
               (Fetcher.fetch
                  (D.Namespace.get_by_name ns name)
                  ("http://do/" ^ op)))
      | _ -> Response.text ~status:`Not_Found "not found")
