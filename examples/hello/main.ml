open Js_of_ocaml

type _ Effect.t += Ask : int -> int Effect.t

let global name = Js.Unsafe.get Js.Unsafe.global (Js.string name)

let sleep ms =
  Workero.Promise.make (fun ~resolve ~reject:_ ->
      ignore
        (Js.Unsafe.fun_call (global "setTimeout")
           [|
             Js.Unsafe.inject (Js.wrap_callback (fun () -> resolve ()));
             Js.Unsafe.inject (ms : int);
           |]))

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
      Promise.await (sleep 50);
      let r = ask_twice () in
      Promise.await (sleep 50);
      Response.text
        (Printf.sprintf "effects across awaited promises ok: %d\n" r)
  | GET, "/fail" ->
      Promise.await (sleep 20);
      raise (Failed (ask_twice ()))
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
