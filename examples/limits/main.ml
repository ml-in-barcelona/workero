let mandelbrot size max_iter =
  let inside = ref 0 and steps = ref 0 in
  for py = 0 to size - 1 do
    for px = 0 to size - 1 do
      let cr = (3.0 *. float px /. float size) -. 2.0
      and ci = (2.0 *. float py /. float size) -. 1.0 in
      let zr = ref 0.0 and zi = ref 0.0 and i = ref 0 in
      while !i < max_iter && (!zr *. !zr) +. (!zi *. !zi) <= 4.0 do
        let t = (!zr *. !zr) -. (!zi *. !zi) +. cr in
        zi := (2.0 *. !zr *. !zi) +. ci;
        zr := t;
        incr i
      done;
      steps := !steps + !i;
      if !i = max_iter then incr inside
    done
  done;
  (!inside, !steps)

let allocate mb =
  let chunks =
    Array.init mb (fun i -> Bytes.make (1024 * 1024) (Char.chr (i land 255)))
  in
  Array.fold_left (fun acc b -> acc + Char.code (Bytes.get b 0)) 0 chunks

let int_param url name ~default =
  match Option.bind (Workero.URL.query url name) int_of_string_opt with
  | Some n when n > 0 -> n
  | _ -> default

let handler req _env _ctx =
  let open Workero in
  let url = Request.url req in
  match URL.path url with
  | "/" ->
      Response.text
        "GET /cpu?n=<grid size>&iter=<max iterations>\n\
         GET /memory?mb=<megabytes to allocate>\n"
  | "/cpu" ->
      let n = int_param url "n" ~default:200
      and iter = int_param url "iter" ~default:200 in
      let inside, steps = mandelbrot n iter in
      Response.text
        (Printf.sprintf
           "mandelbrot %dx%d, max %d iterations\n\
            points inside the set: %d\n\
            inner loop steps: %d\n"
           n n iter inside steps)
  | "/memory" ->
      let mb = int_param url "mb" ~default:16 in
      let check = allocate mb in
      Response.text
        (Printf.sprintf "allocated and touched %d MB (check %d)\n" mb check)
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
