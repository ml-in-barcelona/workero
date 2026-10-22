
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
type context = {
  attempt : int; (* 1 on the first try, 2 on the first retry. *)
}
```
What the runtime tells a step callback about the call.

```ocaml
val do_ : 
  ?retries:retries ->
  ?timeout:Duration.t ->
  t ->
  string ->
  (context -> Jsonkit.t) ->
  Jsonkit.t
```
`do_ step name f` runs `f` as a step and returns its result. `f` gets the [`context`](./#type-context) of the attempt. The result is stored and a replay returns it without calling `f`. `name` identifies the step, so it must be the same on each replay. Without `retries` and `timeout`, the runtime defaults apply: 5 retries, 10 seconds, exponential backoff and a timeout of 10 minutes per attempt.

`f` runs in its own fiber and may call [`Promise.await`](./Workero-Promise.md#val-await). An exception raised by `f` fails the attempt; [`Non_retryable`](./Workero-Workflow.md#exception-Non_retryable) stops the retries. When the step fails for good, `do_` raises [`Js_error`](./Workero.md#exception-Js_error). Catch it to keep the instance running. A step cannot start another step.

Raises `Invalid_argument` when `name` is longer than 256 characters, or when the result has no JSON form.

```ocaml
val sleep : t -> string -> Duration.t -> unit
```
`sleep step name d` sleeps for `d`. The runtime allows up to 365 days.

```ocaml
val sleep_until : t -> string -> float -> unit
```
`sleep_until step name at` sleeps until `at`, milliseconds since the epoch. Use a value computed in a step or taken from the event, so that replays agree.

```ocaml
val wait_for_event : 
  ?timeout:Duration.t ->
  t ->
  string ->
  type_:string ->
  Jsonkit.t
```
`wait_for_event step name ~type_` waits for [`Instance.send_event`](./Workero-Workflow-Instance.md#val-send_event) with the same `type_` and returns its payload. An event sent earlier is kept. `timeout` defaults to 24 hours. When it expires, raises [`Js_error`](./Workero.md#exception-Js_error).

Raises `Invalid_argument` when `type_` is empty, longer than 100 characters or has a character other than letters, digits, `-` and `_`.
