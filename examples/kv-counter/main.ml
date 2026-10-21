let handler _req env _ctx =
  let open Workero in
  let kv = KV.of_env env "COUNTER" in
  let count =
    match KV.get kv "count" with Some s -> int_of_string s | None -> 0
  in
  let count = count + 1 in
  KV.put kv "count" (string_of_int count);
  Response.text (string_of_int count ^ "\n")

let () = Workero.serve handler
