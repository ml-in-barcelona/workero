open Workero

let outcome = ref ""
let pause ms = Promise.await (Util.sleep ms)

let rec echo ws =
  match Websocket.receive ws with
  | Message (Text s) ->
      pause (if s = "slow" then 100 else 10);
      Websocket.send ws (Text s);
      echo ws
  | Message (Binary b) ->
      Websocket.send ws (Binary b);
      echo ws
  | Close { code; reason; _ } as c ->
      outcome :=
        Printf.sprintf "%d:%s:%s" code reason
          (if Websocket.receive ws = c then "same" else "differs");
      Websocket.close ~code ~reason ws
  | Failed _ -> echo ws

let server_close ws =
  Websocket.send ws (Text "hi");
  Websocket.close ~code:4001 ~reason:"server says" ws;
  outcome :=
    match Websocket.send ws (Text "late") with
    | () -> "sent"
    | exception Js_error _ -> "Js_error"

let two_receives ctx ws =
  Context.wait_until ctx (fun () -> ignore (Websocket.receive ws));
  (outcome :=
     match Websocket.receive ws with
     | _ -> "returned"
     | exception Invalid_argument _ -> "Invalid_argument");
  Websocket.close ~code:1000 ws

let handle req _env ctx =
  let route f =
    outcome := "";
    Some (Websocket.upgrade ctx f)
  in
  match URL.path (Request.url req) with
  | "/ws/echo" -> route echo
  | "/ws/server-close" -> route server_close
  | "/ws/two-receives" -> route (two_receives ctx)
  | "/ws/raise" -> route (fun _ -> failwith "boom")
  | "/ws/outcome" -> Some (Response.text !outcome)
  | _ -> None
