
# The workero CLI

`workero` turns an OCaml executable with `(modes wasm)` into a directory that Wrangler can serve and deploy. `workero build` runs dune first. `workero package` works on output that dune already built.


## Usage

```sh
workero build [<dune build args>...] <dir>/<name>.bc.wasm.js [--out <dir>] [--allow-missing-primitives]
workero package <path>/<name>.bc.wasm.js [--out <dir>] [--allow-missing-primitives]
```
`workero` has two options of its own, and both commands take them:

- `--out <dir>` (or `--out=<dir>`) sets the output directory. The default is `_worker`.
- `--allow-missing-primitives` turns the missing-primitives error into a warning.
They can be anywhere in the arguments.


### build

`workero build` is a transparent wrapper of `dune build`. It removes its two own options from the arguments and passes every other argument to `dune build` unchanged and in the same order. There is no `--` separator.

```sh
workero build src/main.bc.wasm.js --profile dev --display short
```
Exactly one argument must end in `.bc.wasm.js`. It is the target to package, written as you would write it for `dune build`, relative to the current directory. With none, or with more than one, `workero` prints a usage error and exits with code 1\. Other targets and aliases in the arguments go to dune, but `workero` does not package them.

Run it from any directory inside the dune project.

`workero build` adds `--profile release` unless the arguments select a profile with `--profile`, `--release`, `-p` or `--for-release-of-packages`, or `DUNE_PROFILE` is set.


### package

`workero package _build/default/src/main.bc.wasm.js` reads `_build/default/src/main.bc.wasm.js` and `_build/default/src/main.bc.wasm.assets` and never runs dune. Use it when another step builds the executable, such as a Makefile or CI job. A path that does not end in `.bc.wasm.js` is a usage error.


## Where it finds the build output

`workero build` finds the output of the `.bc.wasm.js` target the way dune does, so it works when the project is inside another dune project, when you run it from a subdirectory, and when you move the build directory.

1. The dune root is the `--root` directory in the arguments, or `DUNE_ROOT`. With `--release` or `-p` it is the current directory. Otherwise it is the outermost parent directory of the current directory that has a `dune-workspace` file. If there is none, it is the outermost parent that has a `dune-project` file. If there is none, it is the current directory.
2. The build directory is `--build-dir` from the arguments, or `DUNE_BUILD_DIR`, or `_build`. A relative path is relative to the dune root.
3. The output is in `<build directory>/default/<path of the target from the root>`.
With an explicit root (`--root` or `DUNE_ROOT`), dune reads the target relative to that root, not to the current directory, and so does `workero build`. The output is in the directory of the target, and the name is the file name without `.bc.wasm.js`.


## What it does

1. `workero build` only: builds the loader with dune.
2. Removes the `*.wasm.assets` directories that earlier runs left in the output directory, so a second run leaves one set of `.wasm` files.
3. Copies the wasm\_of\_ocaml loader (`<name>.bc.wasm.js`) and its `<name>.bc.wasm.assets` directory into the output directory.
4. Writes `load-wasm.js`, which loads the precompiled wasm modules in workerd.
5. Writes `index.js`, the worker entry point. It imports every `.wasm` file and exports the handlers that the program registered with [`Workero.serve`](./Workero.md#val-serve) and [`Workero.scheduled`](./Workero.md#val-scheduled) and [`Workero.queue`](./Workero.md#val-queue).
It prints `workero: wrote <dir> (<n> wasm file(s))`. On an error it prints `workero: <reason>` to stderr and exits with code 1\.


## Errors

`workero build` and `workero package` exit with code 1 and print `workero: <reason>` to stderr when:

- the arguments do not match the usage,
- `dune build` fails (`workero build` only),
- dune does not produce the loader or the `.wasm.assets` directory (the executable lacks `(modes wasm)`, or the path is wrong),
- the target is outside the dune root (`workero build` only),
- the program uses OCaml functions that have no wasm implementation. The message is `workero: <name> uses functions with no wasm implementation: <list>`. They fail at run time if called. Provide a wasm implementation with `(wasm_of_ocaml (wasm_files ...))`, drop the library that needs them, or pass `--allow-missing-primitives` if they are never called.
The check also works for programs built with `--pretty` in `wasm_of_ocaml` `flags`.


## With Wrangler

Point `main` at the generated `index.js` and run `workero build` as the build command, so `wrangler dev` and `wrangler deploy` rebuild the worker:

```toml
main = "_worker/index.js"

[build]
command = "workero build src/main.bc.wasm.js"
watch_dir = "src"
```
wasm\_of\_ocaml needs `wasm-opt` from binaryen 119 or later on `PATH`. The npm package `binaryen` provides it.


## Advanced: a dune rule

To let dune own the whole build, call `workero package` from a rule in the `dune` file next to the executable:

```dune
(executable
 (name main)
 (modes wasm)
 (libraries workero))

(rule
 (targets (dir worker))
 (deps main.bc.wasm.js main.bc.wasm.assets)
 (action
  (run %{bin:workero} package main.bc.wasm.js --out worker)))
```
`dune build --profile release src/worker` builds the executable and writes the worker to `_build/default/src/worker`.

Point Wrangler at the built directory:

```toml
main = "_build/default/src/worker/index.js"

[build]
command = "dune build --profile release src/worker"
watch_dir = "src"
```
`(targets (dir ...))` is a directory target. Dune 3\.24 and later support it directly. Older versions need `(using directory-targets 0.1)` in `dune-project`.
