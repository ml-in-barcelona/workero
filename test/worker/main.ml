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

let hex s =
  String.concat ""
    (List.init (String.length s) (fun i ->
         Printf.sprintf "%02x" (Char.code s.[i])))

let show_value (v : Workero.D1.value) =
  match v with
  | Null -> "null"
  | Int n -> Printf.sprintf "i:%Ld" n
  | Float f -> Printf.sprintf "f:%g" f
  | Text s -> "t:" ^ s
  | Blob s -> "b:" ^ hex s

let show_row row =
  String.concat "," (List.map (fun (k, v) -> k ^ "=" ^ show_value v) row)

let missing_binding () =
  let open Workero in
  let env = Env.of_js (Js.Unsafe.obj [||]) in
  let message f =
    try
      ignore (f ());
      "no error"
    with Invalid_argument m -> m
  in
  Response.text
    (String.concat "\n"
       [
         message (fun () -> KV.of_env env "NOPE");
         message (fun () -> R2.of_env env "NOPE");
         message (fun () -> D1.of_env env "NOPE");
       ])

let storage req env url =
  let open Workero in
  let arg name = Option.value (URL.query url name) ~default:"" in
  let key = arg "k" in
  match URL.path url with
  | "/kv/get" -> Response.text (opt (KV.get (KV.of_env env "KV") key))
  | "/kv/put" ->
      let expiration_ttl =
        Option.bind (URL.query url "ttl") int_of_string_opt
      in
      KV.put ?expiration_ttl (KV.of_env env "KV") key (arg "v");
      Response.text "ok"
  | "/kv/delete" ->
      KV.delete (KV.of_env env "KV") key;
      Response.text "ok"
  | "/kv/list" ->
      let prefix = URL.query url "prefix" in
      Response.text (String.concat "," (KV.list ?prefix (KV.of_env env "KV")))
  | "/r2/put" ->
      R2.put ?content_type:(URL.query url "type") (R2.of_env env "R2") key
        (Request.bytes req);
      Response.text "ok"
  | "/r2/get" -> (
      match R2.get (R2.of_env env "R2") key with
      | Some bytes -> Response.make bytes
      | None -> Response.text ~status:404 "none")
  | "/r2/head" -> (
      match R2.head (R2.of_env env "R2") key with
      | Some { size; etag; content_type } ->
          Response.text
            (Printf.sprintf "size=%d etag=%s type=%s" size etag
               (opt content_type))
      | None -> Response.text ~status:404 "none")
  | "/r2/delete" ->
      R2.delete (R2.of_env env "R2") key;
      Response.text "ok"
  | "/cache/put" ->
      Cache.put key
        (Response.text
           ~headers:[ ("cache-control", "max-age=60"); ("x-cached", "yes") ]
           (Request.text req));
      Response.text "ok"
  | "/cache/match" -> (
      match Cache.match_ key with
      | Some res ->
          Response.text
            (Printf.sprintf "%d %s %s" (Response.status res)
               (opt (Response.header res "x-cached"))
               (Response.body_text res))
      | None -> Response.text ~status:404 "miss")
  | "/cache/delete" -> Response.text (string_of_bool (Cache.delete key))
  | "/d1/types" ->
      let db = D1.of_env env "DB" in
      let create =
        D1.run db
          "CREATE TABLE IF NOT EXISTS t (n INTEGER, r REAL, s TEXT, b BLOB, z \
           TEXT)"
      in
      let inserted =
        D1.run db "INSERT INTO t (n, r, s, b, z) VALUES (?, ?, ?, ?, ?)"
          ~params:
            [ Int 42L; Float 1.5; Text "h\xc3\xa9llo"; Blob "\000\255\n"; Null ]
      in
      let rows =
        D1.query db "SELECT n, r, s, b, z FROM t WHERE n = ?"
          ~params:[ Int 42L ]
      in
      let count = D1.run db "DELETE FROM t" in
      Response.text
        (String.concat "\n"
           (Printf.sprintf "create=%d inserted=%d deleted=%d" create inserted
              count
           :: List.map show_row rows))
  | "/d1/ints" ->
      let db = D1.of_env env "DB" in
      ignore (D1.run db "CREATE TABLE IF NOT EXISTS ints (n INTEGER)");
      ignore (D1.run db "DELETE FROM ints");
      List.iter
        (fun n ->
          ignore (D1.run db "INSERT INTO ints (n) VALUES (?)" ~params:[ Int n ]))
        [ 3_000_000_000L; -5L; 9_007_199_254_740_992L ];
      Response.text
        (String.concat ";"
           (List.map show_row (D1.query db "SELECT n FROM ints ORDER BY n")))
  | "/d1/int-too-big" -> (
      match
        D1.run (D1.of_env env "DB") "SELECT ?"
          ~params:[ Int 9_007_199_254_740_993L ]
      with
      | _ -> Response.text "unreachable"
      | exception Invalid_argument message -> Response.text ~status:400 message)
  | "/d1/no-params" ->
      let db = D1.of_env env "DB" in
      Response.text
        (String.concat ";"
           (List.map show_row (D1.query db "SELECT 1 AS one, 'x' AS two")))
  | "/d1/error" -> (
      match D1.query (D1.of_env env "DB") "SELEKT nothing" with
      | _ -> Response.text "unreachable"
      | exception Js_error message ->
          Response.text ~status:502 ("sql error: " ^ message))
  | "/d1/sync-throw" -> (
      match D1.query (D1.of_env env "DB") "" with
      | _ -> Response.text "unreachable"
      | exception Js_error message ->
          Response.text ~status:502 ("caught " ^ message))
  | "/d1/columns" ->
      let db = D1.of_env env "DB" in
      Response.text
        (String.concat ";"
           (List.map show_row
              (D1.query db "SELECT 1 AS id, 2 AS id, 3 AS \"10\", 4 AS \"2\"")))
  | "/kv/list-broken" -> (
      match KV.list ~prefix:"kv-broken-" (KV.of_env env "KV") with
      | _ -> Response.text "unreachable"
      | exception Js_error message -> Response.text ~status:502 message)
  | "/binding/shape" ->
      let name = arg "name" in
      let kv () = ignore (KV.of_env env name) in
      let r2 () = ignore (R2.of_env env name) in
      let d1 () = ignore (D1.of_env env name) in
      let message f =
        try
          f ();
          "ok"
        with Invalid_argument m -> m
      in
      Response.text (String.concat "\n" [ message kv; message r2; message d1 ])
  | "/binding/missing" -> missing_binding ()
  | _ -> Response.text ~status:404 "not found\n"

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
  | _, p
    when List.exists
           (fun prefix -> String.starts_with ~prefix p)
           [ "/kv/"; "/r2/"; "/cache/"; "/d1/"; "/binding/" ] ->
      storage req env url
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
