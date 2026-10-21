let handler _req _env _ctx =
  let open Workero in
  let upstream = fetch "https://example.com/" in
  Response.copy
    ~headers:
      (("x-proxied-by", "workero")
      :: List.remove_assoc "x-proxied-by" (Response.headers upstream))
    upstream

let () = Workero.serve handler
