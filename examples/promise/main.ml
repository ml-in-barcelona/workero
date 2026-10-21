let elapsed f =
  let t0 = Workero.Date.now () in
  f ();
  Workero.Date.now () -. t0

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
            Promise.await (Timer.sleep 100);
            Promise.await (Timer.sleep 100))
      in
      Response.text (Printf.sprintf "two awaits of 100 ms: ~%.0f ms\n" ms)
  | GET, "/concurrent" ->
      let ms =
        elapsed (fun () ->
            let a = Timer.sleep 100 and b = Timer.sleep 100 in
            Promise.await a;
            Promise.await b)
      in
      Response.text
        (Printf.sprintf "two timers of 100 ms, awaited: ~%.0f ms\n" ms)
  | GET, "/rejected" -> (
      match Promise.await (Promise.reject (Promise.error_of_string "boom")) with
      | () -> Response.text "unreachable\n"
      | exception Js_error e ->
          Response.text
            (Printf.sprintf "caught Js_error: %s\n" (Promise.error_to_string e))
      )
  | _ -> Response.text ~status:404 "not found\n"

let () = Workero.serve handler
