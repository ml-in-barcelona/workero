let handler _req _env _ctx =
  let open Workero in
  let upstream = fetch "https://example.com/" in
  Response.make ~status:(Response.status upstream)
    ~headers:
      (("x-proxied-by", "workero")
      :: List.remove_assoc "x-proxied-by" (Response.headers upstream))
    (Response.body_bytes upstream)

let () = Workero.serve handler
