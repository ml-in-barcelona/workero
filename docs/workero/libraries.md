
# Supported libraries

This page gives examples of OCaml standard library features and libraries you can use in a Worker. The list is not complete. A successful wasm\_of\_ocaml build alone does not show that every function works in the Workers runtime. Check each feature your code calls, especially if it needs operating system features such as sockets or processes. Dependencies add to the Worker bundle. See [Limits](./limits.md).


## Features in the example worker

The routes in `examples/features/main.mlx` demonstrate these features. The example builds a Worker; the repository test suite does not run these routes. Test the routes you use in `workerd` and in your deployment:

- Effects: OCaml 5 effect handlers; a separate route awaits a Promise.
- `Hashtbl`, `Lazy`, `Seq`, `Printexc` and `Random.State`.
- `Int32`, `Int64`, `Float` and `Bigarray`.
- `Marshal`.
- `Str` regular expressions.
- `Digest`: MD5 and BLAKE2b.
- [`Workero.Timer`](./Workero-Timer.md), [`Workero.Date`](./Workero-Date.md), [`Workero.Crypto`](./Workero-Crypto.md) and [`Workero.Console`](./Workero-Console.md).
- JavaScript interop with `Js_of_ocaml`, for example `JSON`.

## `jsonkit`

[jsonkit](https://github.com/melange-community/jsonkit) reads and writes JSON, with a ppx that derives the functions. [`Workero.JSON`](./Workero-JSON.md) builds on it and gives values as `Jsonkit.t`. It does not re-export jsonkit. opam installs jsonkit with workero. Add `jsonkit` to the `libraries` of your `dune` file to use it. See [JSON](./json.md).


## Server-side React

`examples/react` renders a page from `.mlx` components with a trimmed copy of server-reason-react. It uses the synchronous render path only. This example builds but is not part of the repository's `workerd` test suite.


## Embedded files

A Worker has no file system. To read a file at run time, embed it with the wasm\_of\_ocaml `--file` flag. The program reads it with `open_in`:

```dune
(executable
 (name main)
 (modes wasm)
 (libraries workero)
 (link_deps motd.txt)
 (wasm_of_ocaml
  (flags
   (--file motd.txt:/static/motd.txt))))
```

## Libraries that need native code

A library with C stubs that have no wasm implementation fails the build. `workero build` lists the missing functions. Provide a wasm implementation with `(wasm_of_ocaml (wasm_files ...))`, or drop the library. See [the CLI](./cli.md).


## Differences from native OCaml

- `Sys.word_size` is 32, and `int` has 31 bits.
- The program has no threads or sub-processes. It can open only outbound TCP connections, with [`Workero.Socket`](./Workero-Socket.md).
Successful compilation does not prove that the runtime dependencies of a library are available in a Worker. See [Testing a worker](./testing.md).
