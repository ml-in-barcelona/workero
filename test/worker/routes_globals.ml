open Workero

let timer path =
  let count = ref 0 in
  let bump () = incr count in
  match path with
  | "/timer/sleep" ->
      let t0 = Date.now () in
      Promise.await (Timer.sleep 80);
      Some (Response.text (Printf.sprintf "%.0f" (Date.now () -. t0)))
  | "/timer/set-timeout" ->
      ignore (Timer.set_timeout bump 20);
      Promise.await (Timer.sleep 150);
      Some (Response.text (string_of_int !count))
  | "/timer/clear-timeout" ->
      let t = Timer.set_timeout bump 20 in
      Timer.clear_timeout t;
      Promise.await (Timer.sleep 150);
      Some (Response.text (string_of_int !count))
  | "/timer/interval" ->
      let i = Timer.set_interval bump 20 in
      Promise.await (Timer.sleep 200);
      Timer.clear_interval i;
      let stopped_at = !count in
      Promise.await (Timer.sleep 150);
      Some (Response.text (Printf.sprintf "%d,%d" stopped_at !count))
  | _ -> None

let globals path =
  match path with
  | "/date/now" -> Some (Response.text (Printf.sprintf "%.0f" (Date.now ())))
  | "/date/iso" ->
      let invalid =
        match Date.to_iso_string Float.nan with
        | _ -> "no error"
        | exception Invalid_argument _ -> "invalid"
      in
      Some
        (Response.text
           (String.concat ";"
              [
                Date.to_iso_string 0.;
                Date.to_iso_string 1700000000123.;
                invalid;
              ]))
  | "/crypto/uuid" ->
      Some (Response.text (Crypto.random_uuid () ^ "," ^ Crypto.random_uuid ()))
  | "/crypto/bytes" ->
      let len n = string_of_int (String.length (Crypto.random_bytes n)) in
      let rejected n =
        match Crypto.random_bytes n with
        | _ -> "no error"
        | exception Invalid_argument _ -> "invalid"
      in
      let a = Crypto.random_bytes 32 and b = Crypto.random_bytes 32 in
      Some
        (Response.text
           (String.concat ";"
              [
                String.concat "," (List.map len [ 0; 1; 16; 65536 ]);
                Printf.sprintf "differ=%b" (a <> b);
                Printf.sprintf "nonzero=%b" (a <> String.make 32 '\000');
                rejected (-1);
                rejected 65537;
              ]))
  | "/console/log" ->
      Console.log "console log";
      Console.info "console info";
      Console.warn "console warn";
      Console.error "console error";
      Console.debug "console debug";
      Some (Response.text "logged")
  | _ -> None

let handle req _env _ctx =
  let path = URL.path (Request.url req) in
  match timer path with Some _ as r -> r | None -> globals path
