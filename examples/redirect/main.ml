let handler _req _env _ctx =
  Workero.Response.redirect ~status:`Moved_Permanently "https://example.com/"

let () = Workero.serve handler
