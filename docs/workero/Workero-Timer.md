
# Module `Workero.Timer`

JavaScript timers: `setTimeout`, `setInterval` and their `clear` functions. Delays are in milliseconds. Call them only from inside a handler or a [`Context.wait_until`](https://ml-in-barcelona.github.io/workero/workero/Workero/Context/index.html#val-wait_until) function; the Workers runtime refuses timers at startup.

```ocaml
type timeout
```
A pending `setTimeout`.

```ocaml
type interval
```
A running `setInterval`.

```ocaml
val sleep : int -> unit Promise.t
```
`sleep ms` resolves after `ms` milliseconds. Use `Promise.await (sleep ms)` to wait in direct style.

```ocaml
val set_timeout : (unit -> unit) -> int -> timeout
```
`set_timeout f ms` calls `f` once after `ms` milliseconds, like `setTimeout(f, ms)`. `f` runs outside the handler, so it cannot call [`Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await). An exception raised by `f` is an uncaught JavaScript error.

```ocaml
val clear_timeout : timeout -> unit
```
`clearTimeout`. Clearing a timeout that already ran does nothing.

```ocaml
val set_interval : (unit -> unit) -> int -> interval
```
`set_interval f ms` calls `f` every `ms` milliseconds until [`clear_interval`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-clear_interval), like `setInterval(f, ms)`. `f` follows the rules of [`set_timeout`](https://ml-in-barcelona.github.io/workero/workero/Workero/Timer/index.html#val-set_timeout).

```ocaml
val clear_interval : interval -> unit
```
`clearInterval`.
