let handler _req _env _ctx =
  Workero.Response.redirect ~status:301 "https://example.com/"

let () = Workero.serve handler
