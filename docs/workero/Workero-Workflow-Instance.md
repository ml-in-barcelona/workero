
# Module `Workflow.Instance`

The calls suspend like [`Promise.await`](./Workero-Promise.md#val-await). They raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects, for example for an instance that does not exist.

```ocaml
type t
```
One instance of a Workflow.

```ocaml
type status = 
  | Queued
  | Running
  | Paused
  | Errored
  | Terminated
  | Complete
  | Waiting
  | Waiting_for_pause
  | Unknown
```
```ocaml
type state = {
  status : status;
  error : (string * string) option; (* Error name and message. *)
  output : Rpc.value option; (* What the function of register returned, once complete. *)
}
```
```ocaml
val id : t -> string
```
```ocaml
val status : t -> state
```
The state now.

```ocaml
val pause : t -> unit
```
```ocaml
val resume : t -> unit
```
```ocaml
val terminate : t -> unit
```
```ocaml
val restart : t -> unit
```
Starts again from the beginning.

```ocaml
val send_event : t -> type_:string -> Rpc.value -> unit
```
`send_event i ~type_ payload` delivers an event to [`Step.wait_for_event`](./Workero-Workflow-Step.md#val-wait_for_event). The runtime raises [`Js_error`](./Workero.md#exception-Js_error) when the instance is not running.

Raises `Invalid_argument` when `type_` is not valid, as for [`Step.wait_for_event`](./Workero-Workflow-Step.md#val-wait_for_event).
