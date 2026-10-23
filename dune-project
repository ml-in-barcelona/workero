(lang dune 3.24)

(name workero)

(license MIT)

(maintainers "David Sancho <dsnxmoreno@gmail.com>")

(authors "David Sancho <dsnxmoreno@gmail.com>")

(source
 (github ml-in-barcelona/workero))

(generate_opam_files true)

(package
 (name workero)
 (synopsis "Write Cloudflare Workers in OCaml (via wasm_of_ocaml)")
 (depends
  (ocaml
   (>= 5.4))
  (dune
   (>= 3.24))
  (js_of_ocaml
   (and
    (>= 6.4.1)
    (< 6.5)))
  (wasm_of_ocaml-compiler
   (and
    (>= 6.4.1)
    (< 6.5)))
  (cmdliner
   (>= 2.0))
  (jsonkit
   (and
    (>= 1.1.0)
    (< 2)))
  (html_of_jsx
   (and
    :with-dev-setup
    (>= 0.1.1)))
  (alcotest :with-test)
  (odoc
   (and
    :with-doc
    (>= 3.2.1)))
  (ocamlformat
   (and
    :with-dev-setup
    (= 0.29.0)))))

(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (merlin_reader mlx)
  (format
   (run ocamlformat-mlx %{input-file}))
  (preprocess
   (run mlx-pp %{input-file}))))
