open Js_of_ocaml

exception Failed

let sleep ms =
  Workero.Promise.make (fun ~resolve ~reject:_ ->
      ignore
        (Js.Unsafe.fun_call
           (Js.Unsafe.get Js.Unsafe.global "setTimeout")
           [|
             Js.Unsafe.inject (Js.wrap_callback (fun () -> resolve ()));
             Js.Unsafe.inject (ms : int);
           |]))

let background = ref "unset"
let last_scheduled = ref "none"
let upstream = "http://upstream.test"
let opt = Option.value ~default:"none"
let opt_int = function Some n -> string_of_int n | None -> "none"

let method_name m =
  match (m : Workero.Method.t) with
  | Other s -> "other:" ^ s
  | m -> Workero.Method.to_string m

let echo_upstream () =
  let open Workero in
  let res =
    fetch ~method_:PUT
      ~headers:[ ("x-a", "1"); ("x-b", "2") ]
      ~body:"payload" (upstream ^ "/echo")
  in
  Response.text
    (Printf.sprintf "status=%d upstream=%s body=%s" (Response.status res)
       (opt (Response.header res "x-upstream"))
       (Response.body_text res))

module Json_user = struct
  open Jsonkit.Primitives

  type t = { name : string; age : int } [@@deriving json]
end

let handler req env ctx =
  let open Workero in
  let url = Request.url req in
  match (Request.method_ req, URL.path url) with
  | GET, "/hello" ->
      let name = Option.value (URL.query url "name") ~default:"world" in
      Response.text (Printf.sprintf "hello, %s\n" name)
  | POST, "/echo" -> Response.text (Request.text req)
  | POST, "/json/echo" -> (
      match JSON.parse req with
      | Ok json -> JSON.response json
      | Error message -> JSON.error message)
  | POST, "/json/user" -> (
      match JSON.decode Json_user.of_json req with
      | Ok user -> JSON.response (Json_user.to_json user)
      | Error message -> JSON.error ~status:422 message)
  | POST, "/json/raise" -> JSON.response (JSON.request req)
  | GET, "/json/custom" ->
      JSON.response ~status:201
        ~headers:[ ("Content-Type", "application/vnd.api+json"); ("x-a", "b") ]
        (`List [ `Int 1; `Null ])
  | _, "/method" -> Response.text (method_name (Request.method_ req))
  | _, "/header" -> Response.text (opt (Request.header req "x-test") ^ "\n")
  | _, "/headers" ->
      Request.headers req
      |> List.filter (fun (k, _) -> String.starts_with ~prefix:"x-" k)
      |> List.map (fun (k, v) -> k ^ "=" ^ v)
      |> String.concat ";" |> Response.text
  | _, "/bytes" ->
      let body = Request.bytes req in
      Response.make
        ~headers:
          [
            ("content-type", "application/octet-stream");
            ("x-length", string_of_int (String.length body));
          ]
        body
  | _, "/cf" ->
      let cf = Request.cf req in
      Response.text
        (Printf.sprintf "country=%s city=%s colo=%s asn=%s"
           (opt (Cf.country cf))
           (opt (Cf.city cf))
           (opt (Cf.colo cf))
           (opt_int (Cf.asn cf)))
  | _, "/status" ->
      Response.text ~status:201 ~headers:[ ("x-made", "yes") ] "made\n"
  | _, "/no-content" -> Response.text ~status:204 ""
  | _, "/html" -> Response.html "<p>hi</p>"
  | _, "/html-type" ->
      Response.html ~status:404
        ~headers:[ ("Content-Type", "text/html; charset=latin1") ]
        "<p>gone</p>"
  | _, "/make" ->
      Response.make ~status:202
        ~headers:[ ("content-type", "image/png"); ("x-a", "1") ]
        "\000\137PNG\255"
  | _, "/redirect" -> Response.redirect "http://test/hello"
  | _, "/redirect-301" -> Response.redirect ~status:301 "http://test/hello"
  | _, "/redirect-bad" -> Response.redirect ~status:200 "http://test/hello"
  | _, "/env" -> Response.text (opt (Env.var env "GREETING") ^ "\n")
  | _, "/js" ->
      let ctx_js = Context.to_js ctx in
      Response.text
        (String.concat ";"
           [
             Js.to_string (Js.Unsafe.get (Request.to_js req) "method");
             opt (Env.var (Env.of_js (Env.to_js env)) "GREETING");
             Js.to_string
               (Js.typeof
                  (Js.Unsafe.get
                     (Context.to_js (Context.of_js ctx_js))
                     "waitUntil"));
           ])
  | _, "/js-response" ->
      let init = Js.Unsafe.obj [| ("status", Js.Unsafe.inject 202) |] in
      Response.of_js
        (Js.Unsafe.new_obj
           (Js.Unsafe.get Js.Unsafe.global "Response")
           [| Js.Unsafe.inject (Js.string "raw"); init |])
  | _, "/fetch" -> echo_upstream ()
  | _, "/fetch-get" ->
      Response.text (Response.body_text (fetch (upstream ^ "/echo")))
  | _, "/fetch-raw" ->
      let res =
        fetch ~method_:POST ~body:(Request.bytes req) (upstream ^ "/raw")
      in
      Response.make (Response.body_bytes res)
  | _, "/fetch-headers" ->
      let res = fetch (upstream ^ "/bytes") in
      Response.make
        ~headers:
          [
            ( "x-upstream-headers",
              Response.headers res
              |> List.filter (fun (k, _) -> String.starts_with ~prefix:"x-" k)
              |> List.map (fun (k, v) -> k ^ "=" ^ v)
              |> String.concat ";" );
          ]
        (Response.body_bytes res)
  | _, "/fetch-caught" -> (
      match fetch (upstream ^ "/boom") with
      | _ -> Response.text "unreachable"
      | exception Js_error msg -> Response.text ~status:502 ("caught " ^ msg))
  | _, "/fetch-reject" -> fetch (upstream ^ "/boom")
  | _, "/background/start" ->
      let v = Option.value (URL.query url "v") ~default:"" in
      Context.wait_until ctx (fun () ->
          ignore (Promise.await (sleep 30));
          background := "done:" ^ v);
      Response.text "started"
  | _, "/background/fail" ->
      Context.wait_until ctx (fun () ->
          ignore (Promise.await (sleep 10));
          raise Failed);
      Response.text "started"
  | _, "/scheduled/read" -> Response.text !last_scheduled
  | _, "/background/read" -> Response.text !background
  | _, "/fail" -> raise Failed
  | _, "/reject" ->
      ignore (Promise.await (Promise.reject "nope"));
      Response.text "unreachable\n"
  | _, "/sleep" ->
      ignore (Promise.await (sleep 50));
      Response.text "slept\n"
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler

let () =
  Workero.scheduled (fun controller env ctx ->
      let open Workero in
      let cron = Scheduled.cron controller in
      match cron with
      | "fail" -> raise Failed
      | _ ->
          ignore (Promise.await (sleep 20));
          let upstream_status = Response.status (fetch (upstream ^ "/echo")) in
          Context.wait_until ctx (fun () -> ());
          last_scheduled :=
            Printf.sprintf "cron=%s time=%.0f env=%s upstream=%d" cron
              (Scheduled.scheduled_time controller)
              (opt (Env.var env "GREETING"))
              upstream_status)
