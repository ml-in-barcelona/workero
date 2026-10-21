
# Queue

[`Workero.Queue`](./Workero-Queue.md) sends messages to a [Cloudflare Queue](https://developers.cloudflare.com/queues/). The handler that [`Workero.queue`](./Workero.md#val-queue) registers receives them in batches.

**Name.** Under `open Workero`, `Queue` hides `Stdlib.Queue`. Write `Stdlib.Queue` when you need the standard one.


## Configure

Create the queue, then bind it as a producer and as a consumer in `wrangler.toml`. `binding` is the name that you pass to `of_env`. One Worker can be the producer and the consumer of the same queue:

```sh
npx wrangler queues create jobs
```
```toml
[[queues.producers]]
binding = "JOBS"
queue = "jobs"

[[queues.consumers]]
queue = "jobs"
max_batch_size = 10
max_retries = 3
```

## Send

A message body is a [`Workero.Queue.body`](./Workero-Queue.md#type-body). The constructor sets the content type, so a body and its content type cannot disagree:

- `Json json` sends a [`Workero.JSON`](./Workero-JSON.md) value, as content type `json`.
- `Text s` sends a string, as content type `text`.
- `Bytes s` sends the bytes of `s`, as content type `bytes`.
```ocaml
let handler req env _ctx =
  let open Workero in
  let jobs = Queue.of_env env "JOBS" in
  match URL.path (Request.url req) with
  | "/enqueue" ->
      Queue.send jobs (Queue.Json (`Assoc [ ("id", `Int 7) ]));
      Response.text "queued\n"
  | "/later" ->
      Queue.send ~delay_seconds:60 jobs (Queue.Text "tidy up");
      Response.text "queued\n"
  | "/many" ->
      Queue.send_batch jobs
        [
          Queue.message (Queue.Text "first");
          Queue.message ~delay_seconds:30 (Queue.Bytes "\x00\x01");
        ];
      Response.text "queued\n"
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
- [`Workero.Queue.of_env`](./Workero-Queue.md#val-of_env) opens the producer. It raises `Invalid_argument` when there is no such binding, or when the binding is not a queue producer.
- [`Workero.Queue.send`](./Workero-Queue.md#val-send) adds one message and waits until the queue accepts it.
- [`Workero.Queue.send_batch`](./Workero-Queue.md#val-send_batch) adds several messages in one call. The batch `delay_seconds` applies to the messages that set none with [`Workero.Queue.message`](./Workero-Queue.md#val-message).
- `delay_seconds` is 0 to 86400\. Other values raise `Invalid_argument` before anything is sent.
If the queue rejects a message, for example because it is too large, the call raises [`Workero.Js_error`](./Workero.md#exception-Js_error). See the [Queues limits](https://developers.cloudflare.com/queues/platform/limits/).


## Receive

[`Workero.queue`](./Workero.md#val-queue) registers the consumer. It gets a [`Workero.Queue.Batch.t`](./Workero-Queue-Batch.md#type-t), the `env` and the `ctx`, and returns `unit`. It runs in a fiber, so it can call [`Workero.Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch) and the bindings.

```ocaml
let () =
  Workero.queue (fun batch env _ctx ->
      let open Workero in
      let store = KV.of_env env "KV" in
      List.iter
        (fun message ->
          match Queue.Message.body_json message with
          | `Assoc [ ("id", `Int id) ] ->
              KV.put store ("job:" ^ string_of_int id) "done";
              Queue.Message.ack message
          | _ -> Queue.Message.retry ~delay_seconds:30 message)
        (Queue.Batch.messages batch))
```
A worker can register [`Workero.serve`](./Workero.md#val-serve), [`Workero.scheduled`](./Workero.md#val-scheduled), [`Workero.queue`](./Workero.md#val-queue), or any combination.

Read a body with the function that matches how the producer sent it: [`Workero.Queue.Message.body_json`](./Workero-Queue-Message.md#val-body_json), [`Workero.Queue.Message.body_text`](./Workero-Queue-Message.md#val-body_text) or [`Workero.Queue.Message.body_bytes`](./Workero-Queue-Message.md#val-body_bytes). The runtime gives the consumer the body, not its content type. A `Text` body read with `body_json` is a JSON string. A reader that does not fit the body raises `Invalid_argument`. A message that another producer sent with the `v8` content type is available through [`Workero.Queue.Message.body_js`](./Workero-Queue-Message.md#val-body_js).

[`Workero.Queue.Message.id`](./Workero-Queue-Message.md#val-id), [`Workero.Queue.Message.timestamp`](./Workero-Queue-Message.md#val-timestamp) (milliseconds since the Unix epoch) and [`Workero.Queue.Message.attempts`](./Workero-Queue-Message.md#val-attempts) (1 on the first delivery) describe the delivery.


### Acknowledge and retry

- [`Workero.Queue.Message.ack`](./Workero-Queue-Message.md#val-ack) marks one message as delivered.
- [`Workero.Queue.Message.retry`](./Workero-Queue-Message.md#val-retry) asks for another delivery, after `?delay_seconds` when given.
- [`Workero.Queue.Batch.ack_all`](./Workero-Queue-Batch.md#val-ack_all) and [`Workero.Queue.Batch.retry_all`](./Workero-Queue-Batch.md#val-retry_all) do the same for the whole batch.
If the handler returns without any of these, the runtime counts the batch as delivered. If the handler raises, the event fails and Cloudflare delivers again the messages that the handler did not ack, up to `max_retries`. An [`Workero.Queue.Message.ack`](./Workero-Queue-Message.md#val-ack) called before the exception still counts. See [Batching and retries](https://developers.cloudflare.com/queues/configuration/batching-retries/).


## Test

`wrangler dev` runs producers and consumers on your machine. In `workerd test`, `env.WORKER.queue(name, messages)` runs the consumer and returns which messages were acked or retried. It needs the `service_binding_extra_handlers` compatibility flag on the calling worker and `workerd test --experimental`. The producer binding can point at a small HTTP service that records what the runtime sends. `test/worker/run.sh` shows both.
