let usage =
  "usage: workero build <dir>/<name> [--out <dir>] \
   [--allow-missing-primitives] [-- <dune args>...]\n\
  \       workero package <dir>/<name> [--out <dir>] \
   [--allow-missing-primitives]"

let fail fmt =
  Printf.ksprintf
    (fun s ->
      prerr_endline ("workero: " ^ s);
      exit 1)
    fmt

let read_file path = In_channel.with_open_bin path In_channel.input_all

let write_file path data =
  Out_channel.with_open_bin path (fun oc -> output_string oc data)

let rec remove path =
  match Unix.lstat path with
  | { st_kind = S_DIR; _ } ->
      Array.iter (fun f -> remove (Filename.concat path f)) (Sys.readdir path);
      Unix.rmdir path
  | _ -> Unix.unlink path
  | exception Unix.Unix_error (ENOENT, _, _) -> ()

let rec mkdir_p path =
  if not (Sys.file_exists path) then (
    mkdir_p (Filename.dirname path);
    Unix.mkdir path 0o755)

let rec copy src dst =
  if Sys.is_directory src then (
    mkdir_p dst;
    Array.iter
      (fun f -> copy (Filename.concat src f) (Filename.concat dst f))
      (Sys.readdir src))
  else write_file dst (read_file src)

let rec option name = function
  | [] -> None
  | arg :: value :: _ when arg = name -> Some value
  | arg :: rest ->
      let prefix = name ^ "=" in
      if String.starts_with ~prefix arg then
        let n = String.length prefix in
        Some (String.sub arg n (String.length arg - n))
      else option name rest

let release args =
  List.exists
    (fun arg ->
      arg = "--release" || arg = "-p"
      || String.starts_with ~prefix:"--for-release-of-packages" arg)
    args

let has_profile args =
  Sys.getenv_opt "DUNE_PROFILE" <> None
  || release args
  || List.exists (String.starts_with ~prefix:"--profile") args

let dune_build dune_args target =
  let profile =
    if has_profile dune_args then [] else [ "--profile"; "release" ]
  in
  let argv =
    Array.of_list ((("dune" :: "build" :: profile) @ dune_args) @ [ target ])
  in
  let pid =
    Unix.create_process "dune" argv Unix.stdin Unix.stdout Unix.stderr
  in
  match Unix.waitpid [] pid with
  | _, WEXITED 0 -> ()
  | _, _ -> fail "dune build %s failed" target

let rec ancestors dir =
  let parent = Filename.dirname dir in
  dir :: (if parent = dir then [] else ancestors parent)

let outermost_with files dir =
  List.fold_left
    (fun found d ->
      if List.exists (fun f -> Sys.file_exists (Filename.concat d f)) files then
        Some d
      else found)
    None (ancestors dir)

let find_root ~cwd args =
  let explicit =
    match option "--root" args with
    | Some _ as root -> root
    | None when release args -> Some cwd
    | None -> Sys.getenv_opt "DUNE_ROOT"
  in
  match explicit with
  | Some root when root <> "" ->
      let root =
        if Filename.is_relative root then Filename.concat cwd root else root
      in
      (Unix.realpath root, true)
  | _ -> (
      match outermost_with [ "dune-workspace" ] cwd with
      | Some root -> (root, false)
      | None -> (
          match outermost_with [ "dune-project" ] cwd with
          | Some root -> (root, false)
          | None -> (cwd, false)))

let components path =
  let step acc = function
    | "" | "." -> acc
    | ".." -> ( match acc with _ :: rest -> rest | [] -> acc)
    | part -> part :: acc
  in
  List.rev (List.fold_left step [] (String.split_on_char '/' path))

let rec strip_prefix prefix path =
  match (prefix, path) with
  | [], rest -> Some rest
  | p :: ps, q :: qs when p = q -> strip_prefix ps qs
  | _ -> None

let built_dir dune_args dir =
  let cwd = Unix.realpath (Sys.getcwd ()) in
  let root, explicit = find_root ~cwd dune_args in
  let base = if explicit then root else cwd in
  let absolute d =
    if Filename.is_relative d then Filename.concat base d else d
  in
  let build =
    match (option "--build-dir" dune_args, Sys.getenv_opt "DUNE_BUILD_DIR") with
    | (Some d, _ | None, Some d) when d <> "" -> d
    | _ -> "_build"
  in
  let build =
    if Filename.is_relative build then Filename.concat root build else build
  in
  match strip_prefix (components root) (components (absolute dir)) with
  | Some rel -> String.concat "/" (build :: "default" :: rel)
  | None -> fail "%s is outside the dune root %s" dir root

let missing_primitives loader =
  let stub =
    Str.regexp "Error([ \n\t]*[\"']\\([A-Za-z0-9_]+\\) not implemented[\"']"
  in
  let rec scan pos acc =
    match Str.search_forward stub loader pos with
    | exception Not_found -> List.sort_uniq compare acc
    | _ -> scan (Str.match_end ()) (Str.matched_group 1 loader :: acc)
  in
  scan 0 []

let index_js ~name wasm =
  let buf = Buffer.create 1024 in
  let modules =
    List.mapi
      (fun i file ->
        let path = Printf.sprintf "%s.bc.wasm.assets/%s" name file in
        Printf.bprintf buf "import m%d from \"./%s\";\n" i path;
        Printf.sprintf "\"%s\": m%d" path i)
      wasm
  in
  Printf.bprintf buf
    "import { loadWasmOCaml } from \"./load-wasm.js\";\n\
     await loadWasmOCaml({ %s }, () => import(\"./%s.bc.wasm.js\"));\n\
     %s"
    (String.concat ", " modules)
    name Embedded.index;
  Buffer.contents buf

let package ~allow_missing ~built ~name out =
  let loader = Printf.sprintf "%s.bc.wasm.js" name in
  let loader_src = Filename.concat built loader in
  if not (Sys.file_exists loader_src) then
    fail "loader not found: %s" loader_src;
  let assets = Printf.sprintf "%s.bc.wasm.assets" name in
  let assets_src = Filename.concat built assets in
  if not (Sys.file_exists assets_src) then
    fail "assets not found: %s" assets_src;
  (match missing_primitives (read_file loader_src) with
  | [] -> ()
  | missing ->
      let message =
        Printf.sprintf
          "%s uses functions with no wasm implementation: %s\n\
           They fail at run time if called. Provide a wasm implementation with \
           (wasm_of_ocaml (wasm_files ...)), drop the library that needs them, \
           or pass --allow-missing-primitives if they are never called."
          name
          (String.concat ", " missing)
      in
      if allow_missing then prerr_endline ("workero: warning: " ^ message)
      else fail "%s" message);
  mkdir_p out;
  Array.iter
    (fun f ->
      if Filename.check_suffix f ".wasm.assets" then
        remove (Filename.concat out f))
    (Sys.readdir out);
  copy assets_src (Filename.concat out assets);
  write_file (Filename.concat out loader) (read_file loader_src);
  write_file (Filename.concat out "load-wasm.js") Embedded.load_wasm;
  let wasm =
    Sys.readdir (Filename.concat out assets)
    |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".wasm")
    |> List.sort compare
  in
  write_file (Filename.concat out "index.js") (index_js ~name wasm);
  let count = List.length wasm in
  Printf.printf "workero: wrote %s (%d wasm file%s)\n" out count
    (if count = 1 then "" else "s")

let build ~allow_missing target out dune_args =
  let dir = Filename.dirname target and name = Filename.basename target in
  dune_build dune_args (Printf.sprintf "%s/%s.bc.wasm.js" dir name);
  package ~allow_missing ~built:(built_dir dune_args dir) ~name out

let () =
  let rec parse out allow targets = function
    | [] -> (out, allow, targets)
    | "--out" :: dir :: rest -> parse dir allow targets rest
    | "--allow-missing-primitives" :: rest -> parse out true targets rest
    | arg :: rest -> parse out allow (arg :: targets) rest
  in
  let split args =
    let rec go acc = function
      | [] -> (List.rev acc, None)
      | "--" :: rest -> (List.rev acc, Some rest)
      | arg :: rest -> go (arg :: acc) rest
    in
    go [] args
  in
  match List.tl (Array.to_list Sys.argv) with
  | "build" :: args -> (
      let args, dune_args = split args in
      match parse "_worker" false [] args with
      | out, allow_missing, [ target ] ->
          build ~allow_missing target out (Option.value dune_args ~default:[])
      | _ -> fail "%s" usage)
  | "package" :: args -> (
      match split args with
      | args, None -> (
          match parse "_worker" false [] args with
          | out, allow_missing, [ target ] ->
              package ~allow_missing ~built:(Filename.dirname target)
                ~name:(Filename.basename target) out
          | _ -> fail "%s" usage)
      | _ -> fail "%s" usage)
  | _ -> fail "%s" usage
