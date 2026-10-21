open Workero
module Js = Js_of_ocaml.Js

let sleep ms = Promise.await (Util.sleep ms)
let written = ref 0
let ended = ref "running"
let outcome = ref "none"

let body_info req =
  let chunks = ref 0 in
  let total = ref 0 in
  let sum = ref 0 in
  Option.iter
    (Stream.iter (fun chunk ->
         incr chunks;
         total := !total + String.length chunk;
         String.iter (fun c -> sum := (!sum + Char.code c) mod 65521) chunk))
    (Request.body req);
  Response.text (Printf.sprintf "chunks=%d total=%d sum=%d" !chunks !total !sum)

let chunks ctx =
  Response.stream ctx (fun w ->
      for i = 1 to 5 do
        Stream.Writer.write w (Printf.sprintf "chunk %d\n" i);
        sleep 30
      done)

let back_pressure ctx =
  written := 0;
  Response.stream ctx (fun w ->
      for _ = 1 to 50 do
        Stream.Writer.write w (String.make 65536 'x');
        incr written
      done)

let until_cancelled ctx =
  written := 0;
  ended := "running";
  Response.stream ctx (fun w ->
      try
        for _ = 1 to 1000 do
          Stream.Writer.write w "tick\n";
          incr written;
          sleep 10
        done;
        ended := "finished"
      with
      | Js_error _ -> ended := "Js_error"
      | e -> ended := Printexc.to_string e)

let raises ctx =
  Response.stream ctx (fun w ->
      Stream.Writer.write w "before\n";
      sleep 20;
      failwith "boom")

let observed ctx =
  let real = Context.to_js ctx in
  let settled value =
    Js.wrap_callback (fun (_ : Js.Unsafe.any) -> outcome := value)
  in
  let wait_until (work : Js.Unsafe.any) =
    ignore (Js.Unsafe.meth_call real "waitUntil" [| work |]);
    ignore
      (Js.Unsafe.meth_call work "then"
         [|
           Js.Unsafe.inject (settled "ok");
           Js.Unsafe.inject (settled "rejected");
         |])
  in
  Context.of_js
    (Js.Unsafe.obj
       [| ("waitUntil", Js.Unsafe.inject (Js.wrap_callback wait_until)) |])

let self_close ctx =
  outcome := "pending";
  Response.stream (observed ctx) (fun w ->
      Stream.Writer.write w "x";
      Stream.Writer.close w)

let iter_cancel ctx =
  ended := "running";
  let w, source = Stream.pipe () in
  Context.wait_until ctx (fun () ->
      try
        while true do
          Stream.Writer.write w "x"
        done
      with Js_error _ -> ended := "cancelled");
  (try Stream.iter (fun _ -> failwith "stop") source with Failure _ -> ());
  sleep 100;
  Response.text !ended

let echo ctx req =
  Response.stream ctx (fun w ->
      Option.iter (Stream.iter (Stream.Writer.write w)) (Request.body req))

let cache_clone url =
  let res =
    Response.text
      ~headers:[ ("cache-control", "max-age=60"); ("x-cached", "yes") ]
      "cached-body"
  in
  Cache.put url (Response.clone res);
  res

let upstream = "http://upstream.test"

let pass_through req =
  let res = fetch ~method_:POST ~body:(Request.bytes req) (upstream ^ "/raw") in
  match Response.body res with
  | Some s ->
      Response.of_stream ~status:`Accepted ~headers:[ ("x-pass", "1") ] s
  | None -> Response.text ~status:`Internal_Server_Error "no body"

let copy_headers () =
  let res = fetch (upstream ^ "/bytes") in
  Response.copy ~headers:[ ("x-new", "1") ] res

let handle req _env ctx =
  match (Request.method_ req, URL.path (Request.url req)) with
  | _, "/stream/body" -> Some (body_info req)
  | _, "/stream/chunks" -> Some (chunks ctx)
  | _, "/stream/bp" -> Some (back_pressure ctx)
  | _, "/stream/cancel" -> Some (until_cancelled ctx)
  | _, "/stream/raise" -> Some (raises ctx)
  | _, "/stream/self-close" -> Some (self_close ctx)
  | _, "/stream/iter-cancel" -> Some (iter_cancel ctx)
  | _, "/stream/echo" -> Some (echo ctx req)
  | _, "/stream/state" ->
      Some
        (Response.text
           (Printf.sprintf "written=%d ended=%s outcome=%s" !written !ended
              !outcome))
  | _, "/stream/cache-clone" ->
      Some (cache_clone (Option.value (Request.header req "x-key") ~default:""))
  | _, "/stream/pass" -> Some (pass_through req)
  | _, "/stream/copy" -> Some (copy_headers ())
  | _, "/stream/empty" ->
      Some (Response.empty ~headers:[ ("x-a", "1") ] `Not_Found)
  | _, "/stream/redirect" ->
      Some (Response.redirect ~status:`Temporary_Redirect "/login?x=1")
  | _, "/stream/redirect-abs" -> Some (Response.redirect "http://test/login")
  | _ -> None
