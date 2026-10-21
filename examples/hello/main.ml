type _ Effect.t += Ask : int -> int Effect.t

let ask_twice () =
  Effect.Deep.try_with
    (fun () ->
      let a = Effect.perform (Ask 1) in
      let b = Effect.perform (Ask 2) in
      a + b)
    ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          match e with
          | Ask n ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  Effect.Deep.continue k (n * 10))
          | _ -> None);
    }

exception Failed of int

let handler req _env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" -> Response.text "hello from OCaml\n"
  | GET, "/effects" ->
      Response.text (Printf.sprintf "effects ok: %d\n" (ask_twice ()))
  | GET, "/await" ->
      Promise.await (Timer.sleep 50);
      let r = ask_twice () in
      Promise.await (Timer.sleep 50);
      Response.text
        (Printf.sprintf "effects across awaited promises ok: %d\n" r)
  | GET, "/fail" ->
      Promise.await (Timer.sleep 20);
      raise (Failed (ask_twice ()))
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
