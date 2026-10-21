open Helpers
module R = Workero.Router

let env = Workero.Env.of_js (obj [||])
let ctx = Workero.Context.of_js (obj [||])

let answer_id res =
  match Workero.Response.header res "x-id" with
  | Some id -> id
  | None -> Alcotest.fail "no x-id header"

let answer router meth path =
  match R.find router meth path with
  | R.Found (h, params) ->
      let req = request ("http://test" ^ path) in
      `Found (answer_id (h params req env ctx), params)
  | R.Method_not_allowed ms -> `Not_allowed ms
  | R.Bad_request _ -> `Bad_request
  | R.Not_found -> `Not_found

let route_with meth path id =
  meth path (fun _ _ _ _ -> Workero.Response.text ~headers:[ ("x-id", id) ] "")

let show = function
  | `Found (body, _) -> "found " ^ body
  | `Not_allowed ms ->
      "not allowed " ^ String.concat "," (List.map Workero.Method.to_string ms)
  | `Bad_request -> "bad request"
  | `Not_found -> "not found"

let check_answer router meth path expected =
  let got = show (answer router meth path) in
  Alcotest.(check string) (path ^ " " ^ expected) expected got

let get_ = Workero.Method.GET

let value router meth path name =
  match answer router meth path with
  | `Found (_, params) -> R.param params name
  | other -> Alcotest.failf "%s: %s" path (show other)

let raises_invalid name f =
  match f () with
  | _ -> Alcotest.failf "%s: no exception" name
  | exception Invalid_argument _ -> ()

let test_static_param_catch_all () =
  let router =
    R.make
      [
        route_with R.get "/" "root";
        route_with R.get "/users/me" "me";
        route_with R.get "/users/:id<string>" "user";
        route_with R.get "/users/:id<string>/posts" "posts";
        route_with R.get "/files/:rest<string...>" "files";
        route_with R.get "/files/img/:name<string>" "img";
      ]
  in
  check_answer router get_ "/" "found root";
  check_answer router get_ "/users/me" "found me";
  check_answer router get_ "/users/ann" "found user";
  check_answer router get_ "/users/ann/posts" "found posts";
  check_answer router get_ "/users/ann/other" "not found";
  check_answer router get_ "/files/a" "found files";
  check_answer router get_ "/files/a/b/c" "found files";
  check_answer router get_ "/files/img/x" "found img";
  check_answer router get_ "/files/img/x/y" "found files";
  check_answer router get_ "/files" "not found";
  check_answer router get_ "/nothing" "not found"

let test_params_decoded () =
  let router =
    R.make
      [
        route_with R.get "/n/:id<string>" "n";
        route_with R.get "/f/:rest<string...>" "f";
        route_with R.get "/caf\xc3\xa9" "cafe";
      ]
  in
  let opt = Alcotest.(option string) in
  Alcotest.check opt "utf8" (Some "caf\xc3\xa9")
    (value router get_ "/n/caf%C3%A9" "id");
  Alcotest.check opt "plus stays" (Some "a+b") (value router get_ "/n/a+b" "id");
  Alcotest.check opt "space" (Some "a b") (value router get_ "/n/a%20b" "id");
  Alcotest.check opt "catch-all joined" (Some "one/two/caf\xc3\xa9")
    (value router get_ "/f/one/two/caf%C3%A9" "rest");
  Alcotest.check opt "no such parameter" None (value router get_ "/n/x" "other");
  check_answer router get_ "/caf%C3%A9" "found cafe"

let test_bad_paths () =
  let router = R.make [ route_with R.get "/:id<string>" "x" ] in
  List.iter
    (fun path -> check_answer router get_ path "bad request")
    [
      "/a%2Fb";
      "/a%2fb";
      "/%ZZ";
      "/%4";
      "/%";
      "/.";
      "/..";
      "/%2e";
      "/%2E%2e";
      "/%00";
      "/%1F";
      "/%7F";
      "/%FF";
      "/\xff";
      "/a/";
      "//";
      "";
      "x";
    ];
  check_answer router get_ "/%2e%2e/other" "bad request"

let test_typed_params () =
  let router =
    R.make
      [
        route_with R.get "/i/:n<int>" "int";
        route_with R.get "/b/:v<bool>" "bool";
        route_with R.get "/m/:n<Note_id.t>" "module";
      ]
  in
  check_answer router get_ "/i/42" "found int";
  check_answer router get_ "/i/-5" "found int";
  List.iter
    (fun v -> check_answer router get_ ("/i/" ^ v) "bad request")
    [ "abc"; "0x10"; "1_0"; "+1"; "-"; "1.5"; "99999999999999999999" ];
  check_answer router get_ "/b/true" "found bool";
  check_answer router get_ "/b/false" "found bool";
  check_answer router get_ "/b/yes" "bad request";
  check_answer router get_ "/m/anything" "found module"

let test_methods () =
  let open Workero.Method in
  let router =
    R.make
      [
        route_with R.get "/a" "get a";
        route_with R.post "/a" "post a";
        route_with R.delete "/a" "delete a";
        route_with R.put "/b" "put b";
        route_with R.any "/c" "any c";
        route_with R.get "/c" "get c";
        route_with R.patch "/p" "patch p";
        route_with R.head "/h" "head h";
        route_with R.options "/o" "options o";
      ]
  in
  check_answer router GET "/a" "found get a";
  check_answer router POST "/a" "found post a";
  check_answer router PUT "/a" "not allowed GET,POST,DELETE";
  check_answer router PATCH "/b" "not allowed PUT";
  check_answer router GET "/c" "found get c";
  check_answer router POST "/c" "found any c";
  check_answer router (Other "PURGE") "/c" "found any c";
  check_answer router PATCH "/p" "found patch p";
  check_answer router HEAD "/h" "found head h";
  check_answer router OPTIONS "/o" "found options o";
  check_answer router HEAD "/a" "not found";
  check_answer router OPTIONS "/a" "not found";
  check_answer router (Other "TRACE") "/a" "not found";
  check_answer router (Other "PURGE") "/a" "not allowed GET,POST,DELETE";
  check_answer router POST "/zzz" "not found"

let test_make_rejects () =
  let ok = route_with R.get in
  let rejects name routes =
    raises_invalid name (fun () -> ignore (R.make routes))
  in
  rejects "duplicate" [ ok "/a" "1"; ok "/a" "2" ];
  rejects "duplicate params" [ ok "/a/:x<int>" "1"; ok "/a/:x<int>" "2" ];
  rejects "duplicate any"
    [ route_with R.any "/a" "1"; route_with R.any "/a" "2" ];
  rejects "ambiguous names"
    [ ok "/u/:id<string>" "1"; ok "/u/:name<string>" "2" ];
  rejects "ambiguous crossing"
    [ ok "/:a<string>/x" "1"; ok "/x/:b<string>" "2" ];
  rejects "ambiguous catch-all"
    [ ok "/f/:a<string...>" "1"; ok "/f/:b<string...>" "2" ];
  rejects "ambiguous crossing catch-all"
    [ ok "/foo/:l<string...>" "1"; ok "/:s<string>/bar/:r<string...>" "2" ];
  rejects "ambiguous crossing catch-all, other order"
    [ ok "/:s<string>/bar/:r<string...>" "2"; ok "/foo/:l<string...>" "1" ];
  ignore
    (R.make
       [
         ok "/a" "1";
         route_with R.post "/a" "2";
         route_with R.any "/a" "3";
         ok "/a/:x<string>" "4";
         ok "/a/b/:x<string...>" "5";
         ok "/a/:x<string>/c" "6";
       ])

let test_invalid_patterns () =
  List.iter
    (fun path ->
      raises_invalid path (fun () ->
          ignore (R.make [ route_with R.get path "x" ])))
    [
      "a";
      "/a/";
      "//a";
      "/a//b";
      "/.";
      "/..";
      "/a/../b";
      "/a b";
      "/a%20b";
      "/a?x";
      "/a#x";
      "/\xff";
      "/:id";
      "/:<int>";
      "/:id<>";
      "/:id<float>";
      "/:Id<int>";
      "/:1d<int>";
      "/:id<int";
      "/:id<int>x";
      "/:id<Note_id>";
      "/:id<note.t>";
      "/:id<.t>";
      "/:id<t>";
      "/x:id<int>";
      "/:rest<string...>/more";
      "/:a<string...>/:b<string...>";
    ];
  ignore
    (R.make
       [
         route_with R.get "" "root";
         route_with R.get "/a-b/c_d/e.f/~g/!$&'()*+,;=:@" "chars";
         route_with R.get "/:id'_9<A.B_c.t>" "label";
         route_with R.get "/x/:_<string>" "underscore";
       ])

let test_scope_wrap () =
  let wrap_tag : R.handler -> R.handler =
   fun h params req env ctx ->
    let res = h params req env ctx in
    Workero.Response.text ~headers:[ ("x-id", answer_id res ^ "!") ] ""
  in
  let router =
    R.make
      (R.scope "/api"
         (R.scope "/v1"
            (R.wrap wrap_tag
               [
                 route_with R.get "/" "index";
                 route_with R.get "/users/:id<string>" "user";
               ])
         @ [ route_with R.get "/health" "health" ]))
  in
  check_answer router get_ "/api/v1" "found index!";
  check_answer router get_ "/api/v1/users/7" "found user!";
  check_answer router get_ "/api/health" "found health";
  check_answer router get_ "/users/7" "not found";
  let root = R.make (R.scope "/" [ route_with R.get "/a" "a" ]) in
  check_answer root get_ "/a" "found a";
  raises_invalid "scope with trailing slash" (fun () ->
      ignore (R.scope "/api/" [ route_with R.get "/a" "a" ]));
  raises_invalid "scope catch-all prefix" (fun () ->
      ignore (R.scope "/f/:r<string...>" [ route_with R.get "/a" "a" ]))

let test_param_exn () =
  let router = R.make [ route_with R.get "/u/:id<string>" "u" ] in
  match answer router get_ "/u/1" with
  | `Found (_, params) ->
      Alcotest.(check string) "present" "1" (R.param_exn params "id");
      raises_invalid "absent" (fun () -> ignore (R.param_exn params "nope"))
  | other -> Alcotest.fail (show other)

let run ?(init = []) router path =
  let res =
    R.to_handler router (request ~init ("http://test" ^ path)) env ctx
  in
  (Workero.Response.status res, Workero.Response.header res)

let test_to_handler () =
  let router =
    R.make
      [
        route_with R.get "/a" "a";
        route_with R.post "/a" "post";
        route_with R.get "/q/:id<int>" "q";
      ]
  in
  let status, header = run router "/a" in
  Alcotest.(check (pair int (option string)))
    "found" (200, Some "a")
    (status, header "x-id");
  let status, _ = run router "/missing" in
  Alcotest.(check int) "404" 404 status;
  let status, header = run ~init:[ ("method", jstr "PUT") ] router "/a" in
  Alcotest.(check int) "405" 405 status;
  Alcotest.(check (option string)) "allow" (Some "GET, POST") (header "allow");
  let status, _ = run router "/q/x" in
  Alcotest.(check int) "400 typed" 400 status;
  let status, _ = run router "/a%2Fb" in
  Alcotest.(check int) "400 slash" 400 status;
  let custom =
    R.make
      ~not_found:(fun _ _ _ _ ->
        Workero.Response.text ~status:`Not_Found
          ~headers:[ ("x-id", "custom") ]
          "")
      [ route_with R.get "/a" "a" ]
  in
  let status, header = run custom "/missing" in
  Alcotest.(check (pair int (option string)))
    "custom 404" (404, Some "custom")
    (status, header "x-id")

let test_trailing_slash () =
  let routes = [ route_with R.get "/a" "a"; route_with R.get "/" "root" ] in
  let router = R.make routes in
  let status, header = run router "/a/" in
  Alcotest.(check int) "308" 308 status;
  Alcotest.(check (option string)) "location" (Some "/a") (header "location");
  let status, header = run router "/a///?x=1&y=2" in
  Alcotest.(check int) "308 query" 308 status;
  Alcotest.(check (option string))
    "location query" (Some "/a?x=1&y=2") (header "location");
  let status, _ = run router "//evil.test/" in
  Alcotest.(check int) "protocol-relative is not redirected" 404 status;
  let status, _ = run router "/" in
  Alcotest.(check int) "root" 200 status;
  let reject = R.make ~trailing_slash:`Reject routes in
  let status, _ = run reject "/a/" in
  Alcotest.(check int) "reject" 404 status

let () =
  Alcotest.run "workero.router"
    [
      ( "find",
        [
          Alcotest.test_case "static, parameter, catch-all" `Quick
            test_static_param_catch_all;
          Alcotest.test_case "decoded parameters" `Quick test_params_decoded;
          Alcotest.test_case "bad paths" `Quick test_bad_paths;
          Alcotest.test_case "typed parameters" `Quick test_typed_params;
          Alcotest.test_case "methods" `Quick test_methods;
          Alcotest.test_case "param_exn" `Quick test_param_exn;
        ] );
      ( "make",
        [
          Alcotest.test_case "rejects conflicts" `Quick test_make_rejects;
          Alcotest.test_case "pattern syntax" `Quick test_invalid_patterns;
          Alcotest.test_case "scope and wrap" `Quick test_scope_wrap;
        ] );
      ( "to_handler",
        [
          Alcotest.test_case "answers" `Quick test_to_handler;
          Alcotest.test_case "trailing slash" `Quick test_trailing_slash;
        ] );
    ]
