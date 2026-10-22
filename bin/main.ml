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

let dune_build dune_args =
  let profile =
    if has_profile dune_args then [] else [ "--profile"; "release" ]
  in
  let argv = Array.of_list (("dune" :: "build" :: profile) @ dune_args) in
  let pid =
    Unix.create_process "dune" argv Unix.stdin Unix.stdout Unix.stderr
  in
  match Unix.waitpid [] pid with
  | _, WEXITED 0 -> ()
  | _, _ -> fail "dune build failed"

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

type kind = Durable_object | Entrypoint | Workflow
type class_export = { name : string; kind : kind; methods : string list }

let kind_tag = function
  | Durable_object -> "durable_object"
  | Entrypoint -> "entrypoint"
  | Workflow -> "workflow"

let kind_of_tag = function
  | "durable_object" -> Some Durable_object
  | "entrypoint" -> Some Entrypoint
  | "workflow" -> Some Workflow
  | _ -> None

let kind_glue = function
  | Durable_object ->
      ("durable-object.js", Embedded.durable_object, "WorkeroDurableObject")
  | Entrypoint -> ("entrypoint.js", Embedded.entrypoint, "WorkeroEntrypoint")
  | Workflow -> ("workflow.js", Embedded.workflow, "WorkeroWorkflow")

let glue_files = [ "durable-object.js"; "entrypoint.js"; "workflow.js" ]

let class_exports classes =
  let glue_of c = kind_glue c.kind in
  let imports =
    List.sort_uniq compare
      (List.map
         (fun c ->
           let file, _, base = glue_of c in
           (file, base))
         classes)
  in
  String.concat ""
    (List.map
       (fun (file, base) ->
         Printf.sprintf "import { %s } from \"./%s\";\n" base file)
       imports)
  ^ String.concat ""
      (List.mapi
         (fun i c ->
           let _, _, base = glue_of c in
           let rpc =
             match c.methods with
             | [] -> ""
             | methods ->
                 Printf.sprintf
                   "for (const m of [%s]) workero_class_%d.prototype[m] = \
                    function (...a) { return \
                    this[Symbol.for(\"workero.rpc\")](m, a); };\n"
                   (String.concat ", "
                      (List.map (Printf.sprintf "\"%s\"") methods))
                   i
           in
           Printf.sprintf
             "class workero_class_%d extends %s {\n\
             \  constructor(ctx, env) { super(ctx, env, \"%s\"); }\n\
              }\n\
              %sexport { workero_class_%d as %s };\n"
             i base c.name rpc i c.name)
         classes)

let loader_prelude ~name wasm =
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
     await loadWasmOCaml({ %s }, () => import(\"./%s.bc.wasm.js\"));\n"
    (String.concat ", " modules)
    name;
  Buffer.contents buf

let index_js ~name ~classes wasm =
  loader_prelude ~name wasm ^ Embedded.index ^ class_exports classes

let is_class_name name =
  name <> ""
  && (match name.[0] with '0' .. '9' -> false | _ -> true)
  && (not (List.mem name [ "default"; "then"; "__proto__" ]))
  && String.for_all
       (function
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '$' -> true | _ -> false)
       name

let reserved_methods =
  [
    "fetch";
    "alarm";
    "connect";
    "constructor";
    "prototype";
    "webSocketMessage";
    "webSocketClose";
    "webSocketError";
  ]

let is_method_name name =
  (not (List.mem name reserved_methods)) && is_class_name name

let find_workerd () =
  let executable path = Sys.file_exists path && not (Sys.is_directory path) in
  let path_dirs =
    String.split_on_char ':' (Option.value (Sys.getenv_opt "PATH") ~default:"")
    |> List.filter (fun d -> d <> "")
  in
  let in_path binary = List.map (fun d -> Filename.concat d binary) path_dirs in
  let in_node_modules =
    List.map
      (fun d -> Filename.concat d "node_modules/.bin/workerd")
      (ancestors (Sys.getcwd ()))
  in
  match Sys.getenv_opt "WORKERD" with
  | Some value when value <> "" -> (
      let candidates =
        if String.contains value '/' then [ value ] else in_path value
      in
      match List.find_opt executable candidates with
      | Some path -> path
      | None -> fail "WORKERD is set to %s, which does not exist" value)
  | _ -> (
      match List.find_opt executable (in_path "workerd" @ in_node_modules) with
      | Some path -> path
      | None ->
          fail
            "workerd not found. workero build runs the program in workerd to \
             find its Durable Object classes. Install it (npm install workerd, \
             or wrangler), add it to PATH or set WORKERD")

let probe_marker = "workero-class:"
let probe_end = "workero-classes-end"

let probe_script ~name wasm =
  loader_prelude ~name wasm
  ^ "const kinds = { durable_objects: \"durable_object\", entrypoints: \
     \"entrypoint\", workflows: \"workflow\" };\n\
     export default {\n\
    \  async test() {\n\
    \    for (const [key, kind] of Object.entries(kinds))\n\
    \      for (const [name, factory] of \
     Object.entries(globalThis.__workero?.[key] ?? {}))\n\
    \        console.log(\"" ^ probe_marker
  ^ " \" + [kind, name, ...(factory.rpc ?? [])].join(\" \"));\n\
    \    console.log(\"" ^ probe_end ^ "\");\n  },\n};\n"

let probe_config ~name wasm =
  let modules =
    [ "workero-probe.mjs"; "load-wasm.js"; name ^ ".bc.wasm.js" ]
    |> List.map (fun f ->
        Printf.sprintf "(name = \"%s\", esModule = embed \"%s\")" f f)
  in
  let wasm_modules =
    List.map
      (fun f ->
        let path = Printf.sprintf "%s.bc.wasm.assets/%s" name f in
        Printf.sprintf "(name = \"%s\", wasm = embed \"%s\")" path path)
      wasm
  in
  Printf.sprintf
    "using Workerd = import \"/workerd/workerd.capnp\";\n\
     const config :Workerd.Config = (\n\
    \  services = [(name = \"main\", worker = (\n\
    \    compatibilityDate = \"2025-06-01\",\n\
    \    modules = [%s],\n\
    \  ))],\n\
     );\n"
    (String.concat ", " (modules @ wasm_modules))

let probe_timeout () =
  match
    Option.bind (Sys.getenv_opt "WORKERO_PROBE_TIMEOUT") float_of_string_opt
  with
  | Some seconds when seconds > 0. -> seconds
  | _ -> 30.

let wait_with_timeout pid seconds =
  let deadline = Unix.gettimeofday () +. seconds in
  let rec loop () =
    match Unix.waitpid [ WNOHANG ] pid with
    | 0, _ when Unix.gettimeofday () > deadline ->
        Unix.kill pid Sys.sigkill;
        ignore (Unix.waitpid [] pid);
        None
    | 0, _ ->
        Unix.sleepf 0.05;
        loop ()
    | _, status -> Some status
  in
  loop ()

let parse_class_line line =
  match String.split_on_char ' ' line |> List.filter (( <> ) "") with
  | tag :: name :: methods -> (
      match kind_of_tag tag with
      | None -> Error (Printf.sprintf "unknown class kind %S" tag)
      | Some kind -> (
          if not (is_class_name name) then
            Error (Printf.sprintf "invalid class name %S" name)
          else
            match List.find_opt (fun m -> not (is_method_name m)) methods with
            | Some m ->
                Error
                  (Printf.sprintf "invalid RPC method name %S in class %s" m
                     name)
            | None -> Ok { name; kind; methods }))
  | _ -> Error (Printf.sprintf "unreadable class line %S" line)

let probe_result ~output = function
  | None ->
      Error
        ( output,
          Printf.sprintf
            "the program did not finish initialising in workerd within %g \
             seconds (set WORKERO_PROBE_TIMEOUT to change the limit)"
            (probe_timeout ()) )
  | Some (Unix.WEXITED 0)
    when not
           (List.exists
              (fun line -> String.trim line = probe_end)
              (String.split_on_char '\n' output)) ->
      Error (output, "workerd did not report the registered classes")
  | Some (Unix.WEXITED 0) ->
      let n = String.length probe_marker in
      let lines =
        String.split_on_char '\n' output
        |> List.map String.trim
        |> List.filter (String.starts_with ~prefix:probe_marker)
        |> List.map (fun line -> String.sub line n (String.length line - n))
      in
      let rec parse acc = function
        | [] -> Ok (List.sort (fun a b -> compare a.name b.name) acc)
        | line :: rest -> (
            match parse_class_line line with
            | Error message -> Error ("", message)
            | Ok c ->
                if List.exists (fun x -> x.name = c.name) acc then
                  Error
                    ("", Printf.sprintf "class %s is registered twice" c.name)
                else parse (c :: acc) rest)
      in
      parse [] lines
  | Some _ -> Error (output, "the program failed to initialise in workerd")

let registered_classes ~out ~name wasm =
  let workerd = find_workerd () in
  let files =
    List.map (Filename.concat out)
      [ "workero-probe.mjs"; "workero-probe.capnp"; "workero-probe.log" ]
  in
  let script, config, log =
    match files with [ a; b; c ] -> (a, b, c) | _ -> assert false
  in
  let result =
    Fun.protect
      ~finally:(fun () -> List.iter remove files)
      (fun () ->
        write_file script (probe_script ~name wasm);
        write_file config (probe_config ~name wasm);
        let fd = Unix.openfile log [ O_WRONLY; O_CREAT; O_TRUNC ] 0o644 in
        let pid =
          Unix.create_process workerd
            [| workerd; "test"; config |]
            Unix.stdin fd fd
        in
        let status = wait_with_timeout pid (probe_timeout ()) in
        Unix.close fd;
        probe_result ~output:(read_file log) status)
  in
  match result with
  | Ok classes -> classes
  | Error (output, message) ->
      prerr_string output;
      fail "%s" message

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
  List.iter (fun f -> remove (Filename.concat out f)) glue_files;
  copy assets_src (Filename.concat out assets);
  write_file (Filename.concat out loader) (read_file loader_src);
  write_file (Filename.concat out "load-wasm.js") Embedded.load_wasm;
  let wasm =
    Sys.readdir (Filename.concat out assets)
    |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".wasm")
    |> List.sort compare
  in
  let index = Filename.concat out "index.js" in
  write_file index (index_js ~name ~classes:[] wasm);
  let classes = registered_classes ~out ~name wasm in
  if classes <> [] then (
    List.iter
      (fun c ->
        let file, source, _ = kind_glue c.kind in
        write_file (Filename.concat out file) source)
      classes;
    write_file index (index_js ~name ~classes wasm));
  let count = List.length wasm in
  Printf.printf "workero: wrote %s (%d wasm file%s)\n" out count
    (if count = 1 then "" else "s");
  let names kind =
    List.filter_map
      (fun c -> if c.kind = kind then Some c.name else None)
      classes
  in
  if names Durable_object <> [] then
    Printf.printf "workero: Durable Object classes: %s\n"
      (String.concat ", " (names Durable_object));
  if names Entrypoint <> [] then
    Printf.printf "workero: entrypoint classes: %s\n"
      (String.concat ", " (names Entrypoint));
  if names Workflow <> [] then
    Printf.printf "workero: workflow classes: %s\n"
      (String.concat ", " (names Workflow))

let loader_suffix = ".bc.wasm.js"
let is_loader arg = String.ends_with ~suffix:loader_suffix arg

let split_loader path =
  let n = String.length path - String.length loader_suffix in
  (Filename.dirname path, Filename.basename (String.sub path 0 n))

open Cmdliner

let out =
  let last = List.fold_left (fun _ dir -> dir) "_worker" in
  Term.(
    const last
    $ Arg.(
        value & opt_all string []
        & info [ "out" ] ~docv:"DIR"
            ~doc:
              "Output directory of the worker. The default is $(b,_worker). \
               The last one given wins."))

let allow_missing =
  Arg.(
    value & flag
    & info
        [ "allow-missing-primitives" ]
        ~doc:
          "Turn the missing-primitives error into a warning. Use it when the \
           functions without a wasm implementation are never called.")

let exits =
  [
    Cmd.Exit.info 0 ~doc:"on success.";
    Cmd.Exit.info 1 ~doc:"on usage errors and on run-time errors.";
  ]

let usage_error fmt = Printf.ksprintf (fun s -> `Error (true, s)) fmt

let build_cmd =
  let dune_args =
    Arg.(
      value & pos_all string []
      & info [] ~docv:"DUNE_ARG"
          ~doc:
            "Argument for $(b,dune build), passed unchanged and in order. \
             Exactly one must be the target, a path ending in \
             $(b,.bc.wasm.js).")
  in
  let run out allow_missing dune_args =
    match List.filter is_loader dune_args with
    | [ target ] ->
        dune_build dune_args;
        let dir, name = split_loader target in
        `Ok (package ~allow_missing ~built:(built_dir dune_args dir) ~name out)
    | _ -> usage_error "expected exactly one %s target" loader_suffix
  in
  Cmd.v
    (Cmd.info "build" ~exits
       ~doc:"Run $(b,dune build), then write a worker directory"
       ~man:
         [
           `S Manpage.s_description;
           `P
             "$(b,workero build) wraps $(b,dune build). Every argument that is \
              not a workero option goes to dune unchanged, with no $(b,--) \
              separator. It adds $(b,--profile release) unless the arguments \
              or $(b,DUNE_PROFILE) select a profile.";
           `S Manpage.s_examples;
           `Pre
             "workero build --profile dev src/main.bc.wasm.js --out=x \
              --display quiet";
         ])
    Term.(ret (const run $ out $ allow_missing $ dune_args))

let package_cmd =
  let target =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"TARGET"
          ~doc:
            "Path of the built loader, ending in $(b,.bc.wasm.js). The \
             $(b,.bc.wasm.assets) directory must be next to it.")
  in
  let run out allow_missing target =
    if is_loader target then
      let dir, name = split_loader target in
      `Ok (package ~allow_missing ~built:dir ~name out)
    else usage_error "TARGET must end in %s" loader_suffix
  in
  Cmd.v
    (Cmd.info "package" ~exits
       ~doc:"Write a worker directory from output that dune already built")
    Term.(ret (const run $ out $ allow_missing $ target))

let cmd =
  Cmd.group
    (Cmd.info "workero" ~exits
       ~doc:"Package OCaml wasm_of_ocaml programs as workers")
    [ build_cmd; package_cmd ]

let is_own arg =
  arg = "--allow-missing-primitives"
  || arg = "--help"
  || String.starts_with ~prefix:"--help=" arg
  || String.starts_with ~prefix:"--out=" arg

let split_build args =
  let rec go own rest = function
    | [] -> List.rev_append own ("--" :: List.rev rest)
    | "--out" :: value :: tl -> go (value :: "--out" :: own) rest tl
    | arg :: tl when is_own arg || arg = "--out" -> go (arg :: own) rest tl
    | arg :: tl -> go own (arg :: rest) tl
  in
  go [] [] args

let argv =
  match Array.to_list Sys.argv with
  | prog :: "build" :: args ->
      Array.of_list (prog :: "build" :: split_build args)
  | argv -> Array.of_list argv

let () =
  match Cmd.eval_value ~argv cmd with
  | Ok (`Ok () | `Help | `Version) -> exit 0
  | Error `Exn -> exit Cmd.Exit.internal_error
  | Error (`Parse | `Term) -> exit 1
