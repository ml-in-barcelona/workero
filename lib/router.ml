type params = (string * string) list

let param params name = List.assoc_opt name params

let param_exn params name =
  match param params name with
  | Some value -> value
  | None -> invalid_arg ("Router.param_exn: no parameter " ^ name)

type handler = params -> Request.t -> Env.t -> Context.t -> Response.t

type segment =
  | Static of string
  | Param of string * string
  | Catch_all of string

let is_lower c = (c >= 'a' && c <= 'z') || c = '_'
let is_upper c = c >= 'A' && c <= 'Z'
let is_digit c = c >= '0' && c <= '9'

let valid_label s =
  s <> ""
  && is_lower s.[0]
  && String.for_all
       (fun c -> is_lower c || is_upper c || is_digit c || c = '\'')
       s

let valid_module_name s =
  s <> ""
  && is_upper s.[0]
  && String.for_all
       (fun c -> is_lower c || is_upper c || is_digit c || c = '_' || c = '\'')
       s

let valid_type_name s =
  match String.split_on_char '.' s with
  | [ ("bool" | "int" | "string") ] -> true
  | parts -> (
      match List.rev parts with
      | "t" :: (_ :: _ as modules) -> List.for_all valid_module_name modules
      | _ -> false)

let valid_static s =
  let ok c =
    Char.code c >= 0x80
    || is_lower c || is_upper c || is_digit c
    || String.contains "-.~!$&'()*+,;=:@" c
  in
  s <> "." && s <> ".." && String.for_all ok s

let invalid_pattern path = invalid_arg ("Router: invalid pattern " ^ path)

let parse_param path segment =
  let length = String.length segment in
  match (String.index_opt segment '<', String.index_opt segment '>') with
  | Some opening, Some closing when opening > 1 && closing = length - 1 ->
      let name = String.sub segment 1 (opening - 1) in
      let type_name =
        String.sub segment (opening + 1) (closing - opening - 1)
      in
      if not (valid_label name) then invalid_pattern path
      else if type_name = "string..." then Catch_all name
      else if valid_type_name type_name then Param (name, type_name)
      else invalid_pattern path
  | _ -> invalid_pattern path

let parse_pattern path =
  if path = "" || path = "/" then []
  else if path.[0] <> '/' || not (String.is_valid_utf_8 path) then
    invalid_pattern path
  else
    let segments =
      match String.split_on_char '/' path with
      | _ :: segments -> segments
      | [] -> []
    in
    if List.mem "" segments then invalid_pattern path;
    let segments =
      List.map
        (fun s ->
          if s.[0] = ':' then parse_param path s
          else if valid_static s then Static s
          else invalid_pattern path)
        segments
    in
    let rec final_catch_all = function
      | [] | [ Catch_all _ ] -> true
      | Catch_all _ :: _ -> false
      | _ :: rest -> final_catch_all rest
    in
    if final_catch_all segments then segments else invalid_pattern path

let pattern_to_string = function
  | [] -> "/"
  | segments ->
      "/"
      ^ String.concat "/"
          (List.map
             (function
               | Static s -> s
               | Param (name, type_name) -> ":" ^ name ^ "<" ^ type_name ^ ">"
               | Catch_all name -> ":" ^ name ^ "<string...>")
             segments)

let specificity segments =
  let statics, finite =
    List.fold_left
      (fun (statics, finite) -> function
        | Static _ -> (statics + 1, finite)
        | Param _ -> (statics, finite)
        | Catch_all _ -> (statics, 0))
      (0, 1) segments
  in
  (statics * 2) + finite

let rec overlaps left right =
  match (left, right) with
  | [], [] -> true
  | Catch_all _ :: _, _ :: _ | _ :: _, Catch_all _ :: _ -> true
  | Static a :: left, Static b :: right ->
      String.equal a b && overlaps left right
  | _ :: left, _ :: right -> overlaps left right
  | _ -> false

type route = {
  meth : Method.t option;
  path : string;
  segments : segment list;
  specificity : int;
  handler : handler;
}

let route meth path handler =
  let segments = parse_pattern path in
  { meth; path; segments; specificity = specificity segments; handler }

let get path = route (Some Method.GET) path
let head path = route (Some Method.HEAD) path
let post path = route (Some Method.POST) path
let put path = route (Some Method.PUT) path
let patch path = route (Some Method.PATCH) path
let delete path = route (Some Method.DELETE) path
let options path = route (Some Method.OPTIONS) path
let any path = route None path

let scope prefix routes =
  ignore (parse_pattern prefix);
  let join path =
    if prefix = "/" || prefix = "" then path
    else if path = "/" || path = "" then prefix
    else prefix ^ path
  in
  List.map (fun r -> route r.meth (join r.path) r.handler) routes

let wrap middleware routes =
  List.map (fun r -> { r with handler = middleware r.handler }) routes

type t = {
  routes : route list;
  not_found : handler;
  trailing_slash : [ `Redirect | `Reject ];
}

let default_not_found _ _ _ _ = Response.text ~status:`Not_Found "Not Found"

let check_conflicts routes =
  let rec loop = function
    | [] -> ()
    | r :: rest ->
        List.iter
          (fun other ->
            if r.meth = other.meth then
              if
                String.equal
                  (pattern_to_string r.segments)
                  (pattern_to_string other.segments)
              then invalid_arg ("Router: duplicate route " ^ r.path)
              else if
                r.specificity = other.specificity
                && overlaps r.segments other.segments
              then
                invalid_arg
                  ("Router: ambiguous routes " ^ r.path ^ " and " ^ other.path))
          rest;
        loop rest
  in
  loop routes

let make ?(not_found = default_not_found) ?(trailing_slash = `Redirect) routes =
  check_conflicts routes;
  { routes; not_found; trailing_slash }

type found =
  | Found of handler * params
  | Method_not_allowed of Method.t list
  | Bad_request of string
  | Not_found

let hex_value = function
  | '0' .. '9' as c -> Char.code c - Char.code '0'
  | 'a' .. 'f' as c -> Char.code c - Char.code 'a' + 10
  | 'A' .. 'F' as c -> Char.code c - Char.code 'A' + 10
  | _ -> -1

let decode_segment raw =
  let length = String.length raw in
  let buffer = Buffer.create length in
  let rec unescape i =
    if i >= length then Ok (Buffer.contents buffer)
    else if raw.[i] = '%' then
      let high = if i + 2 < length then hex_value raw.[i + 1] else -1 in
      let low = if i + 2 < length then hex_value raw.[i + 2] else -1 in
      if high < 0 || low < 0 then Error ("malformed escape in " ^ raw)
      else if high = 2 && low = 15 then Error ("encoded slash in " ^ raw)
      else (
        Buffer.add_char buffer (Char.chr ((high lsl 4) lor low));
        unescape (i + 3))
    else (
      Buffer.add_char buffer raw.[i];
      unescape (i + 1))
  in
  match unescape 0 with
  | Error _ as error -> error
  | Ok decoded ->
      if
        decoded = "." || decoded = ".."
        || (not (String.is_valid_utf_8 decoded))
        || String.exists
             (fun c -> Char.code c < 0x20 || Char.code c = 0x7f)
             decoded
      then Error ("invalid segment " ^ raw)
      else Ok decoded

let decode_pathname path =
  if path = "/" then Ok []
  else if path = "" || path.[0] <> '/' then Error ("invalid path " ^ path)
  else
    let raw_segments = List.tl (String.split_on_char '/' path) in
    if List.mem "" raw_segments then Error ("invalid path " ^ path)
    else
      List.fold_right
        (fun raw decoded ->
          match (decode_segment raw, decoded) with
          | Ok segment, Ok rest -> Ok (segment :: rest)
          | Error e, _ | Ok _, Error e -> Error e)
        raw_segments (Ok [])

let match_route route segments =
  let rec loop pattern segments captured =
    match (pattern, segments) with
    | [], [] -> Some (List.rev captured)
    | Static s :: pattern, v :: segments when String.equal s v ->
        loop pattern segments captured
    | Param (name, type_name) :: pattern, v :: segments ->
        loop pattern segments ((name, type_name, v) :: captured)
    | [ Catch_all name ], (_ :: _ as rest) ->
        Some
          (List.rev ((name, "string...", String.concat "/" rest) :: captured))
    | _ -> None
  in
  loop route.segments segments []

let parses_as type_name value =
  match type_name with
  | "int" ->
      let length = String.length value in
      let start = if length > 0 && value.[0] = '-' then 1 else 0 in
      start < length
      && (let rec digits i =
            i >= length || (is_digit value.[i] && digits (i + 1))
          in
          digits start)
      && int_of_string_opt value <> None
  | "bool" -> bool_of_string_opt value <> None
  | _ -> true

let best routes segments =
  List.fold_left
    (fun best route ->
      match match_route route segments with
      | Some captured -> (
          match best with
          | Some (current, _) when current.specificity >= route.specificity ->
              best
          | _ -> Some (route, captured))
      | None -> best)
    None routes

let resolve (route, captured) =
  match
    List.find_opt
      (fun (_, type_name, v) -> not (parses_as type_name v))
      captured
  with
  | Some (name, _, _) -> Bad_request ("invalid path parameter " ^ name)
  | None ->
      Found (route.handler, List.map (fun (name, _, v) -> (name, v)) captured)

let excluded_from_405 = function
  | Method.HEAD | OPTIONS | Other "TRACE" -> true
  | _ -> false

let find t meth path =
  match decode_pathname path with
  | Error reason -> Bad_request reason
  | Ok segments -> (
      let own = List.filter (fun r -> r.meth = Some meth) t.routes in
      let all = List.filter (fun r -> r.meth = None) t.routes in
      match best own segments with
      | Some found -> resolve found
      | None -> (
          match best all segments with
          | Some found -> resolve found
          | None ->
              if excluded_from_405 meth then Not_found
              else
                let allowed =
                  List.fold_left
                    (fun allowed r ->
                      match r.meth with
                      | Some m
                        when (not (List.mem m allowed))
                             && match_route r segments <> None ->
                          allowed @ [ m ]
                      | _ -> allowed)
                    [] t.routes
                in
                if allowed = [] then Not_found else Method_not_allowed allowed))

let strip_trailing_slashes path =
  let length = String.length path in
  let rec stop i = if i > 1 && path.[i - 1] = '/' then stop (i - 1) else i in
  let stop = stop length in
  if stop = length then None else Some (String.sub path 0 stop)

let to_handler t req env ctx =
  let not_found () = t.not_found [] req env ctx in
  let path = Request.path req in
  match strip_trailing_slashes path with
  | Some canonical -> (
      match t.trailing_slash with
      | `Redirect
        when String.starts_with ~prefix:"//" canonical
             || String.starts_with ~prefix:"/\\" canonical ->
          not_found ()
      | `Redirect ->
          let query = Request.query_string req in
          Response.redirect ~status:`Permanent_Redirect
            (if query = "" then canonical else canonical ^ "?" ^ query)
      | `Reject -> not_found ())
  | None -> (
      match find t (Request.method_ req) path with
      | Found (handler, params) -> handler params req env ctx
      | Method_not_allowed allowed ->
          Response.text ~status:`Method_Not_Allowed
            ~headers:
              [
                ("allow", String.concat ", " (List.map Method.to_string allowed));
              ]
            "Method Not Allowed"
      | Bad_request _ -> Response.text ~status:`Bad_Request "Bad Request"
      | Not_found -> not_found ())
