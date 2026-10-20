open Js_of_ocaml

let global name = Js.Unsafe.get Js.Unsafe.global (Js.string name)

let sleep ms =
  Workero.Promise.make (fun ~resolve ~reject:_ ->
      ignore
        (Js.Unsafe.fun_call (global "setTimeout")
           [|
             Js.Unsafe.inject (Js.wrap_callback (fun () -> resolve ()));
             Js.Unsafe.inject (ms : int);
           |]))

let now () =
  Js.to_float (Js.Unsafe.meth_call (global "Date") "now" [||] : Js.number Js.t)

let elapsed f =
  let t0 = now () in
  f ();
  now () -. t0

let handler req _env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" ->
      Response.text
        "JSPI: Promise.await suspends OCaml code in direct style.\n\
         routes: /sequential /concurrent /rejected\n"
  | GET, "/sequential" ->
      let ms =
        elapsed (fun () ->
            Promise.await (sleep 100);
            Promise.await (sleep 100))
      in
      Response.text (Printf.sprintf "two awaits of 100 ms: ~%.0f ms\n" ms)
  | GET, "/concurrent" ->
      let ms =
        elapsed (fun () ->
            let a = sleep 100 and b = sleep 100 in
            Promise.await a;
            Promise.await b)
      in
      Response.text
        (Printf.sprintf "two timers of 100 ms, awaited: ~%.0f ms\n" ms)
  | GET, "/rejected" -> (
      match Promise.await (Promise.reject "boom") with
      | () -> Response.text "unreachable\n"
      | exception Js_error msg ->
          Response.text (Printf.sprintf "caught Js_error: %s\n" msg))
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
