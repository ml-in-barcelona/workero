
# Module `Workero.Workflow`

Cloudflare Workflows: durable, multi-step programs.

A Workflow has two sides. The class side is a function that [`register`](./#val-register) binds to a name; `workero build` exports it as a `WorkflowEntrypoint`, and the Workflows engine runs it step by step. The binding side starts and controls instances from any Worker, like `env.MY_WORKFLOW.create()` in JavaScript. Declare the class in `wrangler.toml`:

```
  [[workflows]]
  name = "my-workflow"
  binding = "MY_WORKFLOW"
  class_name = "Greet"
```
`class_name` is the name given to [`register`](./#val-register).


### Replay

The engine runs the function again after each sleep, wait, retry or eviction. [`Step.do_`](./Workero-Workflow-Step.md#val-do_) returns the stored result of a step that already finished, without calling its callback. So code outside the steps runs again every time: it must be deterministic. Do not read the clock, random numbers or mutable state outside a step; produce the value inside a step and return it. Keep no state in OCaml values between steps, as they are lost on replay. A step callback runs at least once, so make it idempotent.

Step results, event payloads and params are [`Rpc.value`](./Workero-Rpc.md#type-value)s: JSON values and also ``Undefined`, ``Bytes`, ``Date`, ``Bigint`, ``Map` and ``Set`, the types that the runtime stores.

```ocaml
exception Non_retryable of string
```
Raise it in a [`Step.do_`](./Workero-Workflow-Step.md#val-do_) callback to fail the step without retries. The runtime sees a `NonRetryableError` with this message. Raised in the function given to [`register`](./#val-register), it fails the instance.

```ocaml
module Duration : sig ... end
```
```ocaml
type schedule = {
  cron : string;
  scheduled_time : float;
}
```
The cron trigger that started an instance. `scheduled_time` is in milliseconds since the epoch.

```ocaml
type event = {
  payload : Rpc.value; (* The params of create; `Undefined when there were none. *)
  timestamp : float; (* When the instance was created, in milliseconds since the epoch, like Date.now. *)
  instance_id : string;
  workflow_name : string; (* The name of the Workflow. *)
  schedule : schedule option; (* Some _ for an instance started by a cron schedules entry of the binding in wrangler.toml. *)
}
```
The event given to the function of [`register`](./#val-register).

```ocaml
module Step : sig ... end
```
```ocaml
val register : string -> (Env.t -> event -> Step.t -> Rpc.value) -> unit
```
`register class_name run` binds `run` to the class that `workero build` exports under `class_name`. Call it at module initialisation, once per class. `run env event step` runs in a fiber and may call [`Promise.await`](./Workero-Promise.md#val-await). Its result is the output of the instance, and an uncaught exception fails the instance. The runtime creates a new instance of the class for each run.

Raises `Invalid_argument` when `class_name` is not a valid class name (see [`Durable_object.register`](./Workero-Durable_object.md#val-register)), or when it is also the name of a Durable Object class, an entrypoint or another Workflow.

```ocaml
type t
```
A Workflow binding.

```ocaml
val of_env : Env.t -> string -> t
```
`of_env env name` is the Workflow binding `name`.

Raises `Invalid_argument` when `env` has no binding `name`, or when the binding has no `create`, `createBatch` or `get` method.

```ocaml
module Instance : sig ... end
```
The calls suspend like [`Promise.await`](./Workero-Promise.md#val-await). They raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime rejects, for example for an instance that does not exist.

```ocaml
type retention
```
How long the runtime keeps the state of finished instances.

```ocaml
val retention : ?success:Duration.t -> ?error:Duration.t -> unit -> retention
```
`retention ~success ~error ()` keeps a completed instance for `success` and a failed one for `error`. What is left out defaults to the binding's `default_retention` and then to the maximum of the account.

```ocaml
val create : 
  ?id:string ->
  ?params:Rpc.value ->
  ?retention:retention ->
  t ->
  Instance.t
```
`create workflow` starts an instance. `id` defaults to a generated one; `params` is the `payload` of the [`event`](./#type-event). Raises [`Js_error`](./Workero.md#exception-Js_error) when `id` is in use, and `Invalid_argument` when `id` is longer than 100 characters.

```ocaml
type options
```
The arguments of one instance in [`create_batch`](./#val-create_batch).

```ocaml
val options : 
  ?id:string ->
  ?params:Rpc.value ->
  ?retention:retention ->
  unit ->
  options
```
```ocaml
type batch_error = {
  index : int;
  id : string option;
  code : int;
  message : string;
}
```
An instance that [`create_batch`](./#val-create_batch) did not create, for example for an `id` in use.

```ocaml
val create_batch : t -> options list -> Instance.t list * batch_error list
```
`create_batch workflow l` starts up to 100 instances at once. It returns the instances created and the errors, in the order of `l`.

```ocaml
val get : t -> string -> Instance.t
```
`get workflow id` is the instance `id`. Raises [`Js_error`](./Workero.md#exception-Js_error) when it does not exist.

```ocaml
val create_batch_count : 
  ?params:Rpc.value ->
  ?retention:retention ->
  t ->
  count:int ->
  Instance.t list * batch_error list
```
`create_batch_count workflow ~count` starts `count` instances with generated ids and the same `params` and `retention`. Raises `Invalid_argument` when `count` is not in `1..100`.

```ocaml
type delete_error = {
  failed_id : string;
  failed_code : int;
  failed_message : string;
}
```
An instance that [`delete_batch`](./#val-delete_batch) did not delete.

```ocaml
val delete_batch : t -> string list -> string list * delete_error list
```
`delete_batch workflow ids` deletes up to 100 instances at once. It returns the ids deleted and the errors. A running instance stops without running its rollback handlers. Raises `Invalid_argument` when `ids` has no element or more than 100\.
