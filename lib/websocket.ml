open Internal

type message = Text of string | Binary of string

type event =
  | Message of message
  | Close of { code : int; reason : string; was_clean : bool }
  | Failed of string

type t = {
  js : js;
  queue : event Stdlib.Queue.t;
  mutable waiter : (unit -> unit) option;
  mutable closed : event option;
}

type pair = { client : t; server : t }

let of_js js =
  { js; queue = Stdlib.Queue.create (); waiter = None; closed = None }

let to_js t = t.js

let pair () =
  let p = Js.Unsafe.new_obj (global "WebSocketPair") [||] in
  { client = of_js (Js.Unsafe.get p 0); server = of_js (Js.Unsafe.get p 1) }

let push t e =
  (match e with Close _ -> t.closed <- Some e | _ -> ());
  Stdlib.Queue.push e t.queue;
  match t.waiter with
  | Some wake ->
      t.waiter <- None;
      wake ()
  | None -> ()

let listen t name decode =
  let on_event ev : js =
    push t (try decode ev with e -> Failed (Printexc.to_string e));
    Js.Unsafe.inject Js.undefined
  in
  ignore
    (meth t.js "addEventListener"
       [| str name; Js.Unsafe.inject (Js.wrap_callback on_event) |])

let accept t =
  ignore (meth t.js "accept" [||]);
  Js.Unsafe.set t.js "binaryType" (str "arraybuffer");
  listen t "message" (fun ev ->
      let data = Js.Unsafe.get ev "data" in
      if typeof data = "string" then Message (Text (Decode.string data))
      else Message (Binary (Decode.bytes data)));
  listen t "close" (fun ev ->
      Close
        {
          code = Decode.(field "code" int) ev;
          reason = Decode.(field "reason" string) ev;
          was_clean = Decode.(field "wasClean" bool) ev;
        });
  listen t "error" (fun ev ->
      Failed (Option.value (get_string ev "message") ~default:""))

let send t m =
  let data =
    match m with Text s -> str s | Binary b -> Wire.body_of_string b
  in
  ignore (Binding.invoke t.js "send" [| data |])

let rec receive t =
  match (Stdlib.Queue.take_opt t.queue, t.closed) with
  | Some e, _ -> e
  | None, Some c -> c
  | None, None ->
      if t.waiter <> None then
        invalid_arg "Workero.Websocket.receive: another fiber is waiting";
      Promise.await
        (Promise.make (fun ~resolve ~reject:_ ->
             t.waiter <- Some (fun () -> resolve ())));
      receive t

let close ?code ?reason t =
  let args =
    match (code, reason) with
    | None, None -> [||]
    | _ ->
        [|
          Js.Unsafe.inject (Option.value code ~default:1000);
          str (Option.value reason ~default:"");
        |]
  in
  ignore (Binding.invoke t.js "close" args)

let response t =
  let init =
    Js.Unsafe.obj
      [|
        ("status", Js.Unsafe.inject (Status.to_int `Switching_Protocols));
        ("webSocket", t.js);
      |]
  in
  Response.of_js (Js.Unsafe.new_obj (global "Response") [| null; init |])

let is_open t = get_int t.js "readyState" = Some 1

let upgrade ctx f =
  let { client; server } = pair () in
  accept server;
  Context.wait_until ctx (fun () ->
      match f server with
      | () -> if is_open server then close ~code:1000 server
      | exception e ->
          ignore
            (meth (global "console") "error"
               [| str ("Workero.Websocket.upgrade: " ^ Printexc.to_string e) |]);
          if is_open server then close ~code:1011 server);
  response client
