# hello: wasm_of_ocaml on Cloudflare Workers (local)

Setup (local opam root and switch, npm tools):

    export OPAMROOT=$PWD/.opam-root OPAMSWITCH=hello55
    opam switch create hello55 ocaml-base-compiler.5.5.1
    opam install dune js_of_ocaml js_of_ocaml-ppx wasm_of_ocaml-compiler ocamlformat ocaml-lsp-server utop
    npm i -D wrangler binaryen
    export PATH=$PWD/node_modules/.bin:$PATH    # wasm-opt for wasm_of_ocaml
    eval $(opam env)

Build, format, run:

    dune build                       # or --profile release; both work
    dune fmt
    ./mk-worker.sh main worker-main  # copy wasm, loader, load-wasm.js; generate index.js
                                     # BUILD=<dir>/default selects another dune build dir
    ./dev.sh worker-main             # wrangler dev --local on :8787
    curl localhost:8787

`eff` is a second executable that uses OCaml effects with the default JSPI backend (no `--effects=cps`).
Exported functions are wrapped with `globalThis.__promisify` (set by load-wasm.js), so they return promises.
index.js awaits them: `/` runs `run`, `/await` runs `delayed` (effects across awaited promises),
`/fail` runs `failing` (exception after an await gives HTTP 500).
See NOTES.md for results.
