
# Module `Workero.Scheduled`

The `controller` argument of a Worker `scheduled` handler.

```ocaml
type t
```
```ocaml
val cron : t -> string
```
The cron expression that fired, for example `"*/5 * * * *"`.

```ocaml
val scheduled_time : t -> float
```
The time the event was scheduled for, in milliseconds since the Unix epoch.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```