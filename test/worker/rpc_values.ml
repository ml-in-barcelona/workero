open Workero

let methods =
  [
    "same";
    "show";
    "kind";
    "call_fn";
    "make_fn";
    "stream_text";
    "make_stream";
    "stub_text";
    "give_stub";
  ]

let rec show : Rpc.t -> string = function
  | `Undefined -> "undefined"
  | `Null -> "null"
  | `Bool b -> string_of_bool b
  | `Int n -> "int " ^ string_of_int n
  | `Float f -> Printf.sprintf "float %.17g" f
  | `String s -> Printf.sprintf "%S" s
  | `List l -> "[" ^ String.concat ", " (List.map show l) ^ "]"
  | `Assoc l ->
      "{"
      ^ String.concat ", " (List.map (fun (k, v) -> k ^ ": " ^ show v) l)
      ^ "}"
  | `Bytes s -> Printf.sprintf "bytes %S" s
  | `Date f -> Printf.sprintf "date %.17g" f
  | `Bigint s -> "bigint " ^ s
  | `Map l ->
      "map {"
      ^ String.concat ", " (List.map (fun (k, v) -> show k ^ " => " ^ show v) l)
      ^ "}"
  | `Set l -> "set {" ^ String.concat ", " (List.map show l) ^ "}"
  | `Stream _ -> "stream"
  | `Stub _ -> "stub"
  | `Function _ -> "function"

let kind : Rpc.t -> string = function
  | `Undefined -> "undefined"
  | `Null -> "null"
  | `Bool _ -> "boolean"
  | `Int _ | `Float _ -> "number"
  | `String _ -> "string"
  | `List _ -> "Array"
  | `Assoc _ -> "Object"
  | `Bytes _ -> "Uint8Array"
  | `Date _ -> "Date"
  | `Bigint _ -> "bigint"
  | `Map _ -> "Map"
  | `Set _ -> "Set"
  | `Stream _ -> "ReadableStream"
  | `Stub _ -> "Fetcher"
  | `Function _ -> "function"

let text v =
  match Rpc.to_json v with
  | json -> Jsonkit.to_string json
  | exception Invalid_argument _ -> show v

let read_all s =
  let b = Buffer.create 16 in
  Stream.iter (Buffer.add_string b) s;
  Buffer.contents b

let answer ~stub ~spawn name (args : Rpc.t list) : Rpc.t option =
  match (name, args) with
  | "same", [ v ] -> Some v
  | "show", [ v ] -> Some (`String (show v))
  | "kind", [ v ] -> Some (`String (kind v))
  | "call_fn", [ `Function f; x ] -> Some (f [ x ])
  | "make_fn", [] ->
      Some
        (`Function
           (function
           | [ `Int n ] -> `Int (n + 1)
           | _ -> invalid_arg "make_fn: one int"))
  | "stream_text", [ `Stream s ] -> Some (`String (read_all s))
  | "make_stream", [] ->
      let w, r = Stream.pipe () in
      spawn (fun () ->
          Stream.Writer.write w "abc";
          Stream.Writer.write w "def";
          Stream.Writer.close w);
      Some (`Stream r)
  | "stub_text", [ `Stub s ] ->
      Some (`String (Response.body_text (Fetcher.fetch s "http://x/p")))
  | "give_stub", [] -> Some (`Stub (stub ()))
  | _ -> None

let values : (string * Rpc.t) list =
  [
    ("undefined", `Undefined);
    ("null", `Null);
    ("bool", `Bool true);
    ("int", `Int 42);
    ("float", `Float 1.5);
    ("nan", `Float Float.nan);
    ("negative zero", `Float (-0.));
    ("string", `String "h\xc3\xa9llo");
    ("list", `List [ `Int 1; `String "a"; `Null ]);
    ("object", `Assoc [ ("a", `Int 1) ]);
    ("bytes", `Bytes "\000\001\255");
    ("empty bytes", `Bytes "");
    ("date", `Date 86400000.);
    ("bigint", `Bigint "123456789012345678901234567890");
    ("negative bigint", `Bigint "-5");
    ("map", `Map [ (`Int 1, `String "a"); (`String "k", `List [ `Date 0. ]) ]);
    ("set", `Set [ `Int 1; `String "x" ]);
    ( "nested",
      `Assoc
        [
          ("a", `List [ `Undefined; `Date 5. ]);
          ("b", `Map [ (`String "k", `Set [ `Bigint "1" ]) ]);
        ] );
  ]
