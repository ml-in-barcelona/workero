
# Module `Container.Process`

A program started by [`exec`](./Workero-Durable_object-Container.md#val-exec).

```ocaml
type t
```
```ocaml
type output = {
  stdout : string;
  stderr : string;
  exit_code : int;
}
```
```ocaml
val pid : t -> int
```
The process id, inside the container.

```ocaml
val is_pty : t -> bool
```
`true` when [`exec`](./Workero-Durable_object-Container.md#val-exec) gave a `pty`.

```ocaml
val stdin : t -> Stream.Writer.t option
```
A writer for the standard input, when [`exec`](./Workero-Durable_object-Container.md#val-exec) had `stdin:`Pipe`, or a `pty` and no `stdin`. Close it to send the end of input. Each call takes a new writer of the same stream, so call it once.

```ocaml
val stdout : t -> Stream.t option
```
The standard output, unless [`exec`](./Workero-Durable_object-Container.md#val-exec) had `stdout:`Ignore`.

```ocaml
val stderr : t -> Stream.t option
```
The standard error, unless [`exec`](./Workero-Durable_object-Container.md#val-exec) had `stderr:`Ignore` or `stderr:`Combined`, or a `pty`.

```ocaml
val exit_code : t -> int
```
Waits for the process to end. Suspends.

```ocaml
val output : t -> output
```
Reads standard output and standard error to the end and waits for the process to end. It consumes the streams: do not read them as well. Suspends.

```ocaml
val kill : ?signal:int -> t -> unit
```
Sends a Unix signal number to the process, `15` (SIGTERM) by default.

```ocaml
val resize : t -> cols:int -> rows:int -> unit
```
Resizes the terminal of a process started with `pty`. Raises [`Js_error`](./Workero.md#exception-Js_error) for another process, or when `cols` or `rows` is outside 1 to 65535\.
