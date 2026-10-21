let handler _req _env _ctx =
  Workero.JSON.response
    (`Assoc [ ("hello", `String "world"); ("answer", `Int 42) ])

let () = Workero.serve handler
