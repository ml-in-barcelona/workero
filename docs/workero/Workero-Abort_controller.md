
# Module `Workero.Abort_controller`

`AbortController`: aborts an [`Abort_signal`](./Workero-Abort_signal.md).

```ocaml
type t
```
```ocaml
val create : unit -> t
```
```ocaml
val signal : t -> Abort_signal.t
```
The signal to pass to the work that `abort` cancels.

```ocaml
val abort : ?reason:[ `Abort of string | `Timeout of string ] -> t -> unit
```
`abort c` aborts the signal of `c`. ``Abort msg` gives an `AbortError` and ``Timeout msg` a `TimeoutError` with that message. Listeners registered with [`Abort_signal.on_abort`](./Workero-Abort_signal.md#val-on_abort) run in their own fibers; `abort` does not wait for them. Aborting twice does nothing.
