
# Module `Workflow.Step`

```ocaml
type t
```
The step object of one run.

```ocaml
type backoff = 
  | Constant
  | Linear
  | Exponential
```
```ocaml
type retries
```
How to retry a failed step.

```ocaml
type config = {
  retries_limit : int option; (* The retry limit that applies to the step, if the runtime reports one. *)
  backoff : backoff option;
}
```
The retry configuration that the runtime reports for a step. It leaves out `delay` and `timeout`, which the runtime reports as a number or a string.

```ocaml
type context = {
  attempt : int; (* 1 on the first try, 2 on the first retry. *)
  step_name : string;
  step_count : int; (* 1 for the first step with this name, 2 for the second. *)
  config : config;
}
```
What the runtime tells a step callback about the call.

```ocaml
type delay_context = {
  delay_ctx : context;
  delay_error : string * string; (* Name and message of the error that failed the attempt. *)
}
```
What the runtime gives to the function of [`retries_with`](./#val-retries_with).

```ocaml
val retries_with : 
  ?backoff:backoff ->
  limit:int ->
  (delay_context -> Duration.t) ->
  retries
```
`retries_with ~limit f` is like [`retries`](./#val-retries), with the delay before each retry computed by `f` from the failed attempt. `f` runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await).

Raises `Invalid_argument` when `limit` is not in `0..10000`.

```ocaml
val retries : 
  ?backoff:backoff ->
  limit:int ->
  delay:Duration.t ->
  unit ->
  retries
```
`retries ~limit ~delay ()` retries up to `limit` times, waiting `delay` before the first retry. `backoff` defaults to what the runtime defaults to, `Exponential`.

Raises `Invalid_argument` when `limit` is not in `0..10000`.

```ocaml
type rollback_context = {
  rollback_ctx : context; (* The context of the step. *)
  rollback_error : string * string; (* Name and message of the error that made the runtime roll back. *)
  rollback_output : Rpc.value; (* What the step returned. *)
}
```
```ocaml
type rollback
```
A handler that undoes a step.

```ocaml
val rollback : 
  ?retries:retries ->
  ?timeout:Duration.t ->
  (rollback_context -> unit) ->
  rollback
```
`rollback f` runs `f` to undo a step. The runtime calls it, in reverse order of the steps, when the instance fails or when [`Instance.terminate`](./Workero-Workflow-Instance.md#val-terminate) has `~rollback:true`. `retries` and `timeout` apply to the handler. `f` runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await).

```ocaml
val do_ : 
  ?retries:retries ->
  ?timeout:Duration.t ->
  ?rollback:rollback ->
  t ->
  string ->
  (context -> Rpc.value) ->
  Rpc.value
```
`do_ step name f` runs `f` as a step and returns its result. `f` gets the [`context`](./#type-context) of the attempt. The result is stored and a replay returns it without calling `f`. `name` identifies the step, so it must be the same on each replay. Without `retries` and `timeout`, the runtime defaults apply: 5 retries, a delay of 10 seconds, exponential backoff, and a timeout of 10 minutes for each attempt.

`f` runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await). An exception raised by `f` fails the attempt; [`Non_retryable`](./Workero-Workflow.md#exception-Non_retryable) stops the retries. When the step fails for good, `do_` raises [`Js_error`](./Workero.md#exception-Js_error). Catch it to keep the instance running. A step cannot start another step.

Raises `Invalid_argument` when `name` is longer than 256 characters, or when the result has no [`Rpc.value`](./Workero-Rpc.md#type-value) form.

```ocaml
val sleep : t -> string -> Duration.t -> unit
```
`sleep step name d` sleeps for `d`. The runtime allows up to 365 days.

```ocaml
val sleep_until : t -> string -> float -> unit
```
`sleep_until step name at` sleeps until `at`, milliseconds since the epoch. Use a value computed in a step or taken from the event, so that replays agree.

```ocaml
type step_event = {
  event_type : string;
  event_payload : Rpc.value;
  event_timestamp : float; (* When the runtime received the event, in milliseconds since the epoch. *)
}
```
An event that [`Instance.send_event`](./Workero-Workflow-Instance.md#val-send_event) delivered.

```ocaml
val wait_for_event : 
  ?timeout:Duration.t ->
  t ->
  string ->
  type_:string ->
  step_event
```
`wait_for_event step name ~type_` waits for [`Instance.send_event`](./Workero-Workflow-Instance.md#val-send_event) with the same `type_` and returns the event. An event sent earlier is kept. `timeout` defaults to 24 hours. When it expires, raises [`Js_error`](./Workero.md#exception-Js_error).

Raises `Invalid_argument` when `type_` is empty, longer than 100 characters or has a character other than letters, digits, `-` and `_`.
