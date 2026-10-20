# workero template

A Cloudflare Worker written in OCaml. Copy this directory to start.

```sh
opam install workero      # or: opam pin add workero <path-to-workero> -y
npm install               # also installs binaryen, which wasm_of_ocaml needs
npx wrangler dev          # builds src/main.ml, serves on localhost:8787
npx wrangler deploy
```

Routes: `GET /`, `POST /echo`, `GET /env` (reads `GREETING` from `[vars]`).
