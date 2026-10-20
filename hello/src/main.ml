open Js_of_ocaml

exception Boom of int

let compute () =
  let l = List.init 10 (fun i -> i * i) in
  let sum = List.fold_left ( + ) 0 l in
  let caught =
    try raise (Boom sum) with Boom n -> Printf.sprintf "caught Boom %d" n
  in
  let caught2 =
    try
      ignore (List.assoc 99 [ (1, 2) ]);
      "no"
    with Not_found -> "Not_found ok"
  in
  Printf.sprintf "hello from OCaml %s: sum=%d; %s; %s; %.3f" Sys.ocaml_version
    sum caught caught2 (sqrt 2.)

let () =
  Js.export "hello"
    object%js
      method run = Js.string (compute ())
    end
