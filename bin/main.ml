let usage = "usage: workero build <dir>/<name> [--out <dir>]"

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

let dune_build target =
  let pid =
    Unix.create_process "dune"
      [| "dune"; "build"; "--profile"; "release"; target |]
      Unix.stdin Unix.stdout Unix.stderr
  in
  match Unix.waitpid [] pid with
  | _, WEXITED 0 -> ()
  | _, _ -> fail "dune build %s failed" target

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

let build target out =
  let dir = Filename.dirname target and name = Filename.basename target in
  let loader = Printf.sprintf "%s.bc.wasm.js" name in
  let built = Filename.concat "_build/default" dir in
  dune_build (Printf.sprintf "%s/%s" dir loader);
  let loader_src = Filename.concat built loader in
  if not (Sys.file_exists loader_src) then
    fail "loader not found: %s" loader_src;
  let assets = Printf.sprintf "%s.bc.wasm.assets" name in
  let assets_src = Filename.concat built assets in
  if not (Sys.file_exists assets_src) then
    fail "assets not found: %s" assets_src;
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
  Printf.printf "workero: wrote %s (%d wasm file(s))\n" out (List.length wasm)

let () =
  match List.tl (Array.to_list Sys.argv) with
  | [ "build"; target ] -> build target "_worker"
  | [ "build"; target; "--out"; out ] | [ "build"; "--out"; out; target ] ->
      build target out
  | _ -> fail "%s" usage
