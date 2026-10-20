open Js_of_ocaml
open Effect
open Effect.Deep

type _ Effect.t += Ask : int -> int Effect.t
type _ Effect.t += Await : 'a Promise.t -> 'a Effect.t

let global name = Js.Unsafe.get Js.Unsafe.global name

let promising (f : 'a -> 'b) : Js.Unsafe.any =
  Js.Unsafe.fun_call (global "__promisify") [| Js.Unsafe.inject f |]

let async (f : unit -> Js.js_string Js.t) : Js.Unsafe.any =
  let r = Js.Unsafe.meth_call (global "Promise") "withResolvers" [||] in
  let p = Js.Unsafe.get r "promise" in
  let settle name v =
    ignore (Js.Unsafe.fun_call (Js.Unsafe.get r name) [| Js.Unsafe.inject v |])
  in
  try_with
    (fun () ->
      match f () with
      | v -> settle "resolve" v
      | exception e -> settle "reject" (Js.string (Printexc.to_string e)))
    ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          match e with
          | Await p ->
              Some
                (fun (k : (a, _) continuation) ->
                  ignore
                    (Promise.then_
                       (fun v ->
                         ignore
                           (Js.Unsafe.fun_call
                              (promising (fun () -> continue k v))
                              [||]);
                         Promise.resolve ())
                       p))
          | _ -> None);
    };
  p

let await p = perform (Await p)

let sleep (ms : int) =
  Promise.make (fun ~resolve ~reject:_ ->
      ignore
        (Js.Unsafe.fun_call (global "setTimeout")
           [|
             Js.Unsafe.inject (Js.wrap_callback (fun () -> resolve ()));
             Js.Unsafe.inject ms;
           |]))

let now () =
  Js.to_float (Js.Unsafe.meth_call (global "Date") "now" [||] : Js.number Js.t)

let ask_twice () =
  try_with
    (fun () ->
      let a = perform (Ask 1) in
      let b = perform (Ask 2) in
      a + b)
    ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          match e with
          | Ask n -> Some (fun (k : (a, _) continuation) -> continue k (n * 10))
          | _ -> None);
    }

let run () =
  async (fun () -> Js.string (Printf.sprintf "effects ok: %d" (ask_twice ())))

let delayed () =
  async (fun () ->
      let t0 = now () in
      await (sleep 50);
      let r = ask_twice () in
      await (sleep 50);
      Js.string
        (Printf.sprintf "effects across awaited promises ok: %d (%.0f ms)" r
           (now () -. t0)))

let () =
  Js.export "hello"
    (Js.Unsafe.obj [| ("run", promising run); ("delayed", promising delayed) |])
