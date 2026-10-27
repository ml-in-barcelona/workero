
# Workflows

A [Workflow](https://developers.cloudflare.com/workflows/) is a durable, multi-step program. Each step runs at least once, its result is stored, and the runtime can sleep, retry and resume the program for days. [`Workero.Workflow`](./Workero-Workflow.md) covers both halves: the class that runs the steps, and the binding that starts and controls instances.


## Write a Workflow

Register the class under a name at module initialisation. The function gets the `env`, the event and the step object:

```ocaml
open Workero
module Step = Workflow.Step

let () =
  Workflow.register "Greet" (fun _env event step ->
      let name =
        Step.do_ step "read name" (fun _ ->
            match event.Workflow.payload with
            | `Assoc [ ("name", `String n) ] -> `String n
            | _ -> `String "world")
      in
      Step.sleep step "pause" (Workflow.Duration.seconds 10);
      let greeting =
        Step.do_ step "greet"
          ~retries:
            (Step.retries ~limit:3 ~delay:(Workflow.Duration.seconds 5)
               ~backoff:Step.Exponential ())
          ~timeout:(Workflow.Duration.minutes 1)
          (fun { Step.attempt; _ } ->
            let res = fetch "https://example.com/greeting" in
            Console.log (Printf.sprintf "greeting, attempt %d" attempt);
            `String (Response.body_text res))
      in
      `Assoc [ ("name", name); ("greeting", greeting) ])
```
The function runs in a fiber and may call [`Workero.Promise.await`](./Workero-Promise.md#val-await). Its result is the output of the instance, an [`Workero.Rpc.value`](./Workero-Rpc.md#type-value). An exception that it raises fails the instance. The runtime creates a new instance of the class for each run.

`workero build` runs the program once in `workerd` and exports every registered class from `index.js`, like Durable Object and entrypoint classes. It writes `workflow.js` only when a Workflow is registered, so a Worker without Workflows imports nothing new. Declare the class in `wrangler.toml`. `class_name` is the name given to [`Workero.Workflow.register`](./Workero-Workflow.md#val-register), and `binding` is the name that [`Workero.Workflow.of_env`](./Workero-Workflow.md#val-of_env) reads:

```toml
[[workflows]]
name = "greet"
binding = "GREET"
class_name = "Greet"
```

## Replay

The runtime runs the function again after every sleep, wait, retry and eviction. [`Workero.Workflow.Step.do_`](./Workero-Workflow-Step.md#val-do_) returns the stored result of a step that already finished and does not call its callback. So:

- Code outside the steps runs again each time. It must be deterministic: do not read the clock or random numbers there. Produce the value inside a step and return it, as in the example.
- OCaml values do not live between runs. Keep what later steps need in the results of earlier steps.
- A step is identified by its name and the number of calls with that name. Do not rename or reorder the steps of instances that already run.
- A step callback runs at least once. Make it idempotent.

## Steps

- [`Workero.Workflow.Step.do_`](./Workero-Workflow-Step.md#val-do_): run a callback and store its [`Workero.Rpc.value`](./Workero-Rpc.md#type-value) result. The callback gets a [`Workero.Workflow.Step.context`](./Workero-Workflow-Step.md#type-context) with the `attempt` number: 1 on the first try, 2 on the first retry. [`Workero.Workflow.Step.retries`](./Workero-Workflow-Step.md#val-retries) sets `limit` (0 to 10000\), `delay` and `backoff` (`Constant`, `Linear` or `Exponential`). `timeout` applies to each attempt. Without them the runtime uses 5 retries, a 10 second delay, exponential backoff and a 10 minute timeout. A step name has at most 256 characters. The callback also gets the step name, the step count (2 for the second step with that name) and the retry configuration. [`Workero.Workflow.Step.retries_with`](./Workero-Workflow-Step.md#val-retries_with) computes each retry delay from the failed attempt. `~rollback` takes a [`Workero.Workflow.Step.rollback`](./Workero-Workflow-Step.md#val-rollback) handler that undoes the step: the runtime calls the handlers in reverse order when the instance fails or when [`Workero.Workflow.Instance.terminate`](./Workero-Workflow-Instance.md#val-terminate) has `~rollback:true`.
- [`Workero.Workflow.Step.sleep`](./Workero-Workflow-Step.md#val-sleep) and [`Workero.Workflow.Step.sleep_until`](./Workero-Workflow-Step.md#val-sleep_until): wait for a [`Workero.Workflow.Duration.t`](./Workero-Workflow-Duration.md#type-t) or until a time in milliseconds since the epoch, like [`Workero.Date.now`](./Workero-Date.md#val-now).
- [`Workero.Workflow.Step.wait_for_event`](./Workero-Workflow-Step.md#val-wait_for_event): wait for an event of a given `type_`, sent with [`Workero.Workflow.Instance.send_event`](./Workero-Workflow-Instance.md#val-send_event), and return the event: its type, payload and timestamp. The type has 1 to 100 letters, digits, `-` or `_`. It fails with [`Workero.Js_error`](./Workero.md#exception-Js_error) after the timeout (24 hours by default). Catch the error to go on.
Build a [`Workero.Workflow.Duration.t`](./Workero-Workflow-Duration.md#type-t) with [`Workero.Workflow.Duration.ms`](./Workero-Workflow-Duration.md#val-ms), [`Workero.Workflow.Duration.seconds`](./Workero-Workflow-Duration.md#val-seconds), [`Workero.Workflow.Duration.minutes`](./Workero-Workflow-Duration.md#val-minutes), [`Workero.Workflow.Duration.hours`](./Workero-Workflow-Duration.md#val-hours) or [`Workero.Workflow.Duration.days`](./Workero-Workflow-Duration.md#val-days). A negative count raises `Invalid_argument`.

A callback that raises fails the attempt, and the runtime retries it. Raise [`Workero.Workflow.Non_retryable`](./Workero-Workflow.md#exception-Non_retryable) to fail without retries; the runtime sees a `NonRetryableError`. After the last attempt, [`Workero.Workflow.Step.do_`](./Workero-Workflow-Step.md#val-do_) raises [`Workero.Js_error`](./Workero.md#exception-Js_error) in the function; catch it to keep the instance running.

Step results, event payloads, params and outputs are [`Workero.Rpc.value`](./Workero-Rpc.md#type-value)s: the values that `structuredClone` copies. They hold JSON values and also ``Undefined`, ``Bytes`, ``Date`, ``Bigint`, ``Map` and ``Set`. A value converts to a [`Workero.Rpc.t`](./Workero-Rpc.md#type-t) with `(v :> Rpc.t)`, and [`Workero.Rpc.to_value`](./Workero-Rpc.md#val-to_value) converts back. A number above 1073741823, such as `Date.now ()`, is a ``Float`. A step result or payload that has no `Rpc.value` form raises `Invalid_argument`.


## Start and control instances

Read the binding with [`Workero.Workflow.of_env`](./Workero-Workflow.md#val-of_env):

```ocaml
open Workero

let handler _req env _ctx =
  let greet = Workflow.of_env env "GREET" in
  let instance =
    Workflow.create greet ~params:(`Assoc [ ("name", `String "Ana") ])
  in
  let state = Workflow.Instance.status instance in
  Response.text
    (Workflow.Instance.id instance
    ^ (match state.status with
      | Workflow.Instance.Complete -> " complete"
      | _ -> " running"))

let () = serve handler
```
The response body is the instance id followed by ` running`. The first sleep of the instance lasts 10 seconds, so it has not completed.

[`Workero.Workflow.create`](./Workero-Workflow.md#val-create) takes an optional `id` and `params`. The params are the `payload` of the event. [`Workero.Workflow.create_batch`](./Workero-Workflow.md#val-create_batch) takes a list of [`Workero.Workflow.options`](./Workero-Workflow.md#val-options), starts up to 100 instances, and returns the instances and the errors, for example for an `id` in use. [`Workero.Workflow.get`](./Workero-Workflow.md#val-get) finds an instance by id. [`Workero.Workflow.create_batch_count`](./Workero-Workflow.md#val-create_batch_count) starts 1 to 100 instances with the same params and generated ids, and [`Workero.Workflow.delete_batch`](./Workero-Workflow.md#val-delete_batch) deletes up to 100 instances by id. [`Workero.Workflow.create`](./Workero-Workflow.md#val-create), [`Workero.Workflow.options`](./Workero-Workflow.md#val-options) and [`Workero.Workflow.create_batch_count`](./Workero-Workflow.md#val-create_batch_count) take a [`Workero.Workflow.retention`](./Workero-Workflow.md#val-retention) that sets how long the runtime keeps a finished instance.

The [`Workero.Workflow.event`](./Workero-Workflow.md#type-event) of the function also has the `workflow_name` and the cron `schedule` of an instance that a `schedules` entry of the binding started.

An instance has [`Workero.Workflow.Instance.id`](./Workero-Workflow-Instance.md#val-id), [`Workero.Workflow.Instance.status`](./Workero-Workflow-Instance.md#val-status), [`Workero.Workflow.Instance.pause`](./Workero-Workflow-Instance.md#val-pause), [`Workero.Workflow.Instance.resume`](./Workero-Workflow-Instance.md#val-resume), [`Workero.Workflow.Instance.terminate`](./Workero-Workflow-Instance.md#val-terminate), [`Workero.Workflow.Instance.restart`](./Workero-Workflow-Instance.md#val-restart), [`Workero.Workflow.Instance.delete`](./Workero-Workflow-Instance.md#val-delete) and [`Workero.Workflow.Instance.send_event`](./Workero-Workflow-Instance.md#val-send_event). `restart ~from` keeps the stored results of the steps before the one named by [`Workero.Workflow.Instance.restart_from`](./Workero-Workflow-Instance.md#val-restart_from). The calls suspend like [`Workero.Promise.await`](./Workero-Promise.md#val-await). They raise [`Workero.Js_error`](./Workero.md#exception-Js_error) when the runtime rejects them, for example for a missing instance, an `id` in use, or a `send_event` to an instance that is not running. [`Workero.Workflow.create`](./Workero-Workflow.md#val-create), [`Workero.Workflow.options`](./Workero-Workflow.md#val-options) and `send_event` raise `Invalid_argument` for an `id` over 100 characters or an invalid event type.

[`Workero.Workflow.Instance.status`](./Workero-Workflow-Instance.md#val-status) returns a [`Workero.Workflow.Instance.state`](./Workero-Workflow-Instance.md#type-state): the `status`, the `error` as a name and a message, and the `output` once the instance completes.

To use a Workflow of another Worker, add `script_name` to the `[[workflows]]` entry in the `wrangler.toml` of the caller.


## Limits

The runtime enforces its [limits](https://developers.cloudflare.com/workflows/reference/limits/): 1,024 steps (free) or 10,000 (paid, up to 25,000) per instance, 1 MiB for a step result and for an event payload, 365 days for a sleep, and an instance id of up to 100 characters. See the [open issues](https://github.com/ml-in-barcelona/workero/issues) for what workero leaves out.
