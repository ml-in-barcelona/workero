module Js = Js_of_ocaml.Js
open Internal

type t = js
type secure_transport = Off | On | Starttls
type info = { remote_address : string option; local_address : string option }

let transport_name = function
  | Off -> "off"
  | On -> "on"
  | Starttls -> "starttls"

let connect_function () =
  let f = Js.Unsafe.get (Registry.root ()) "connect" in
  if typeof f <> "function" then
    failwith
      "Workero.Socket.connect: cloudflare:sockets is not available here; run \
       the program as a Worker built by workero build";
  f

let connect ?(secure_transport = Off) ?(allow_half_open = false) ~host ~port ()
    =
  if host = "" then invalid_arg "Workero.Socket.connect: host is empty";
  if port < 1 || port > 65535 then
    invalid_arg
      (Printf.sprintf "Workero.Socket.connect: port %d is outside 1 to 65535"
         port);
  let address =
    Binding.options
      [ ("hostname", str host); ("port", Js.Unsafe.inject (port : int)) ]
  in
  let options =
    Binding.options
      [
        ("secureTransport", str (transport_name secure_transport));
        ("allowHalfOpen", Js.Unsafe.inject (Js.bool allow_half_open));
      ]
  in
  let f = connect_function () in
  Binding.guard (fun () ->
      call f [| Js.Unsafe.inject address; Js.Unsafe.inject options |])

let await_property socket name =
  Promise.await (Promise.of_js ~decode:Decode.unit (Js.Unsafe.get socket name))

let opened s = await_property s "opened"

let info s =
  Promise.await
    (Promise.of_js
       ~decode:(fun v ->
         {
           remote_address =
             Decode.field "remoteAddress" (Decode.option Decode.string) v;
           local_address =
             Decode.field "localAddress" (Decode.option Decode.string) v;
         })
       (Js.Unsafe.get s "opened"))

let upgraded s = Decode.bool (Js.Unsafe.get s "upgraded")
let closed s = await_property s "closed"
let reader s = Stream.reader (Stream.of_js (Js.Unsafe.get s "readable"))

let writer s =
  Stream.Writer.of_js
    (Binding.invoke (Js.Unsafe.get s "writable") "getWriter" [||])

let close s = Binding.call ~decode:Decode.unit s "close" [||]

let start_tls ?expected_server_hostname s =
  let args =
    match expected_server_hostname with
    | Some h ->
        [|
          Js.Unsafe.inject
            (Binding.options [ ("expectedServerHostname", str h) ]);
        |]
    | None -> [||]
  in
  Binding.invoke s "startTls" args

let of_js (v : js) : t = v
let to_js (t : t) : js = t
