open Js_of_ocaml

type _ Effect.t += Yield : int -> unit Effect.t

let global name = Js.Unsafe.get Js.Unsafe.global (Js.string name)
let call obj name args = Js.Unsafe.meth_call obj name args
let str_of v = Js.to_string (Js.Unsafe.coerce v)

let sleep ms =
  Workero.Promise.make (fun ~resolve ~reject:_ ->
      ignore
        (Js.Unsafe.fun_call (global "setTimeout")
           [|
             Js.Unsafe.inject (Js.wrap_callback (fun () -> resolve ()));
             Js.Unsafe.inject (ms : int);
           |]))

let effects () =
  let seen = ref [] in
  Effect.Deep.try_with
    (fun () ->
      for i = 1 to 5 do
        Effect.perform (Yield (i * i))
      done)
    ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          match e with
          | Yield n ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  seen := n :: !seen;
                  Effect.Deep.continue k ())
          | _ -> None);
    };
  Printf.sprintf "a generator yielded %s\n"
    (String.concat ", " (List.rev_map string_of_int !seen))

let await () =
  Workero.Promise.await (sleep 50);
  "awaited a setTimeout Promise in direct style\n"

let js () =
  let uuid = str_of (call (global "crypto") "randomUUID" [||]) in
  let json =
    str_of
      (call (global "JSON") "stringify" [| Js.Unsafe.inject (Js.float 1.5) |])
  in
  let epoch =
    let date =
      Js.Unsafe.new_obj (global "Date") [| Js.Unsafe.inject (Js.float 0.) |]
    in
    str_of (call date "toISOString" [||])
  in
  Printf.sprintf
    "crypto.randomUUID: %s\nJSON.stringify 1.5: %s\nnew Date(0): %s\n" uuid json
    epoch

let numbers () =
  let a = Bigarray.Array1.create Bigarray.float64 Bigarray.c_layout 4 in
  Bigarray.Array1.fill a 0.25;
  let sum = ref 0. in
  for i = 0 to 3 do
    sum := !sum +. Bigarray.Array1.get a i
  done;
  Printf.sprintf
    "max_int: %d\n\
     Int32.max_int + 1: %ld\n\
     Int64.max_int: %Ld\n\
     0.1 +. 0.2: %.17g\n\
     float64 bigarray sum: %g\n"
    max_int
    (Int32.add Int32.max_int 1l)
    Int64.max_int (0.1 +. 0.2) !sum

let marshal () =
  let v = ([ 1; 2; 3 ], "text", 2.5, Some 7L) in
  let bytes = Marshal.to_string v [] in
  let back : int list * string * float * int64 option =
    Marshal.from_string bytes 0
  in
  Printf.sprintf "marshalled %d bytes, round trip equal: %b\n"
    (String.length bytes) (back = v)

let hashtbl () =
  let h = Hashtbl.create 16 in
  List.iter
    (fun w -> Hashtbl.replace h w (String.length w))
    [ "wasm"; "of"; "ocaml" ];
  let pairs =
    List.sort compare (Hashtbl.fold (fun k v acc -> (k, v) :: acc) h [])
  in
  Printf.sprintf "%s\nHashtbl.hash \"wasm\": %d\n"
    (String.concat " "
       (List.map (fun (k, v) -> Printf.sprintf "%s=%d" k v) pairs))
    (Hashtbl.hash "wasm")

let regex () =
  let re = Str.regexp "\\([a-z]+\\)@\\([a-z.]+\\)" in
  let s = "mail ada@example.org and bob@ocaml.org" in
  let at = Str.search_forward re s 0 in
  let user = Str.matched_group 1 s and host = Str.matched_group 2 s in
  Printf.sprintf "first match at %d: user %s, host %s\nreplaced: %s\n" at user
    host
    (Str.global_replace re "\\1 at \\2" s)

let digest () =
  Printf.sprintf "MD5: %s\nBLAKE2b-256: %s\n"
    (Digest.to_hex (Digest.string "workero"))
    (Digest.BLAKE256.to_hex (Digest.BLAKE256.string "workero"))

let lazy_seq () =
  let evaluated = ref 0 in
  let v =
    lazy
      (incr evaluated;
       42)
  in
  let sum = Lazy.force v + Lazy.force v in
  let squares = Seq.(take 5 (map (fun n -> n * n) (ints 1))) in
  Printf.sprintf "lazy forced twice, evaluated %d time(s), sum %d\nseq: %s\n"
    !evaluated sum
    (String.concat " " (List.of_seq (Seq.map string_of_int squares)))

let backtrace () =
  Printexc.record_backtrace true;
  match List.assoc "missing" [ ("a", 1) ] with
  | _ -> "unreachable\n"
  | exception e ->
      Printf.sprintf "caught %s\nbacktrace recording: %b\n"
        (Printexc.to_string e)
        (Printexc.backtrace_status ())

let random () =
  let st = Random.State.make [| 2026 |] in
  let draws = List.init 5 (fun _ -> Random.State.int st 100) in
  Printf.sprintf "seeded draws: %s\n"
    (String.concat " " (List.map string_of_int draws))

let file () = In_channel.with_open_bin "/static/motd.txt" In_channel.input_all

let sys () =
  Printf.sprintf "OCaml %s, word size %d, int size %d, backend %s\n"
    Sys.ocaml_version Sys.word_size Sys.int_size
    (match Sys.backend_type with
    | Native -> "native"
    | Bytecode -> "bytecode"
    | Other s -> s)

let routes =
  [
    ("/effects", "OCaml 5 effect handlers: a generator", effects);
    ("/await", "Workero.Promise.await on a setTimeout Promise (JSPI)", await);
    ("/js", "JS interop: crypto, JSON, Date; floats via Js.float", js);
    ("/numbers", "31-bit int, Int32, Int64, floats, Bigarray", numbers);
    ("/marshal", "Marshal round trip", marshal);
    ("/hashtbl", "Hashtbl", hashtbl);
    ("/regex", "Str regular expressions", regex);
    ("/digest", "Digest: MD5 and BLAKE2b", digest);
    ("/lazy", "Lazy and Seq", lazy_seq);
    ("/backtrace", "exceptions and Printexc", backtrace);
    ("/random", "seeded Random.State", random);
    ("/file", "a file embedded with --file, read with open_in", file);
    ("/sys", "Sys facts", sys);
  ]

let index () =
  String.concat ""
    (List.map
       (fun (path, doc, _) -> Printf.sprintf "%-11s %s\n" path doc)
       routes)

let handler req _env =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | "GET", "/" -> Response.text (index ())
  | "GET", path -> (
      match List.find_opt (fun (p, _, _) -> p = path) routes with
      | Some (_, _, run) -> Response.text (run ())
      | None -> Response.text ~status:404 "not found\n")
  | _ -> Response.text ~status:405 "method not allowed\n"

let () = Workero.fetch handler
