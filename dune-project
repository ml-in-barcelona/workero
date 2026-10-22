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
  (jsonkit
   (and
    (>= 1.1.0)
    (< 2)))
  (html_of_jsx
   (and
    :with-dev-setup
    (>= 0.1.0)))
  (alcotest :with-test)
  (odoc
   (and
    :with-doc
    (>= 3.2.1)))
  (ocamlformat
   (and
    :with-dev-setup
    (= 0.29.0)))))

(package
 (name workerd)
 (synopsis "The workerd runtime for Cloudflare Workers")
 (description
  "Installs the prebuilt workerd binary from Cloudflare for your platform: Linux or macOS, x86_64 or arm64. Linux needs glibc 2.35 or later.")
 (license Apache-2.0)
 (authors "Cloudflare, Inc.")
 (homepage "https://github.com/cloudflare/workerd"))

(package
 (name wrangler)
 (synopsis "Wrangler, the Cloudflare Workers command line tool")
 (description
  "Wrangler builds, runs and deploys Cloudflare Workers. This package installs a bundle of Wrangler and its JavaScript dependencies. It uses the workerd package as its runtime. It needs Node.js 22 or later.")
 (license "MIT OR Apache-2.0")
 (authors "Cloudflare, Inc.")
 (homepage
  "https://github.com/cloudflare/workers-sdk/tree/main/packages/wrangler"))

(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (merlin_reader mlx)
  (format
   (run ocamlformat-mlx %{input-file}))
  (preprocess
   (run mlx-pp %{input-file}))))
