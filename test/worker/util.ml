open Js_of_ocaml

let sleep ms =
  Workero.Promise.make (fun ~resolve ~reject:_ ->
      ignore
        (Js.Unsafe.fun_call
           (Js.Unsafe.get Js.Unsafe.global "setTimeout")
           [|
             Js.Unsafe.inject (Js.wrap_callback (fun () -> resolve ()));
             Js.Unsafe.inject (ms : int);
           |]))
