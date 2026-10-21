
# The workero CLI

`workero build` turns an OCaml executable with `(modes wasm)` into a directory that Wrangler can serve and deploy.


## Usage

```sh
workero build <dir>/<name> [--out <dir>]
```
Run it from the root of the dune project. `<dir>/<name>` names the executable: `workero build src/main` builds `src/main.ml`. `--out` sets the output directory. The default is `_worker`.


## What it does

1. Runs `dune build --profile release <dir>/<name>.bc.wasm.js`.
2. Removes the `*.wasm.assets` directories that earlier runs left in the output directory, so a second run leaves one set of `.wasm` files.
3. Copies the wasm\_of\_ocaml loader (`<name>.bc.wasm.js`) and its `<name>.bc.wasm.assets` directory into the output directory.
4. Writes `load-wasm.js`, which loads the precompiled wasm modules in workerd.
5. Writes `index.js`, the worker entry point. It imports every `.wasm` file and exports the handlers that the program registered with [`Workero.serve`](./Workero.md#val-serve) and [`Workero.scheduled`](./Workero.md#val-scheduled).
It prints `workero: wrote <dir> (<n> wasm file(s))`. On an error it prints `workero: <reason>` to stderr and exits with code 1\.


## Errors

`workero build` exits with code 1 and prints `workero: <reason>` to stderr when:

- the arguments do not match the usage,
- `dune build` fails,
- dune does not produce the loader or the `.wasm.assets` directory (the executable lacks `(modes wasm)`, or the path is wrong),
- the program uses OCaml functions that have no wasm implementation. The message is `workero: <name> uses functions with no wasm implementation: <list>`. They would fail at run time. Provide a wasm implementation with `(wasm_of_ocaml (wasm_files ...))`, or drop the library that needs them.
The check also works for programs built with `--pretty` in `wasm_of_ocaml` `flags`.


## With Wrangler

Point `main` at the generated `index.js` and run `workero build` as the build command, so `wrangler dev` and `wrangler deploy` rebuild the worker:

```toml
main = "_worker/index.js"

[build]
command = "workero build src/main"
watch_dir = "src"
```
wasm\_of\_ocaml needs `wasm-opt` from binaryen 119 or later on `PATH`. The npm package `binaryen` provides it.
