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
 (synopsis "Write Cloudflare Workers in OCaml with wasm_of_ocaml")
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
  (ocamlformat :with-dev-setup)))
