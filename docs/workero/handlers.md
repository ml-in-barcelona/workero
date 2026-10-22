
# Handlers

Register the event handlers that your Worker needs at the top level of its OCaml program. [`Workero.serve`](./Workero.md#val-serve) handles HTTP requests, [`Workero.scheduled`](./Workero.md#val-scheduled) handles cron triggers, [`Workero.queue`](./Workero.md#val-queue) consumes Queue messages and [`Workero.email`](./Workero.md#val-email) receives email. Each registration is independent: a cron-only or queue-only Worker does not need an HTTP handler.


## Handle HTTP requests

[`Workero.serve`](./Workero.md#val-serve) takes a function with the same three arguments as a JavaScript `fetch(request, env, ctx)` handler. It returns a [`Workero.Response.t`](./Workero-Response.md#type-t). This `src/main.ml` responds to a request and reads a variable from `env`:

```ocaml
open Workero

let handler req env ctx =
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" ->
      Context.wait_until ctx (fun () ->
          Promise.await (Timer.sleep 100);
          print_endline "request answered");
      Response.text
        (Option.value (Env.var env "GREETING") ~default:"hello" ^ "\n")
  | POST, "/echo" -> Response.text (Request.text req)
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
With `GREETING = "hi"` in the `[vars]` section of `wrangler.toml`, `curl http://localhost:8787/` returns `hi`. The `env` argument also contains resource bindings. Use functions such as [`Workero.KV.of_env`](./Workero-KV.md#val-of_env) and [`Workero.Queue.of_env`](./Workero-Queue.md#val-of_env) to look them up. See [Variables and secrets](./env.md) and [Bindings](./bindings.md).

[`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until) runs work in another fiber that can continue after the response. Its function can wait for JavaScript Promises; failures there are logged and do not change the response. If your Worker runs on a route with an origin, [`Workero.Context.pass_through_on_exception`](./Workero-Context.md#val-pass_through_on_exception) lets the origin answer when the request handler raises. It has no effect on `workers.dev` or without an origin. See [Async and background work](./async.md) for waits and background work.


## Handle cron triggers

Add this `src/main.ml` for a Worker that only handles cron events:

```ocaml
let () =
  Workero.scheduled (fun controller _env _ctx ->
      Printf.printf "cron %s scheduled for %.0f\n%!"
        (Workero.Scheduled.cron controller)
        (Workero.Scheduled.scheduled_time controller))
```
Configure `wrangler.toml`:

```toml
[triggers]
crons = ["*/5 * * * *"]
```
[`Workero.Scheduled.scheduled_time`](./Workero-Scheduled.md#val-scheduled_time) gives milliseconds since the Unix epoch. With `npx wrangler dev --test-scheduled` running, use this command to fire the trigger locally:

```sh
curl "http://localhost:8787/__scheduled?cron=*/5+*+*+*+*"
```
The Worker logs a line beginning `cron */5 * * * * scheduled for `. The timestamp varies with the event.


## Consume Queue messages

[`Workero.queue`](./Workero.md#val-queue) takes a [`Workero.Queue.Batch.t`](./Workero-Queue-Batch.md#type-t), `env` and `ctx`. It returns `unit`. Register it at the top level, as with the other handlers. The [Queue guide](./queue.md) shows a producer binding, consumer configuration, body decoding and acknowledgement in a complete Worker.


## Receive email

[`Workero.email`](./Workero.md#val-email) takes a [`Workero.Email.t`](./Workero-Email.md#type-t), `env` and `ctx`. It returns `unit`. The handler forwards, replies to or rejects the message. The [Email guide](./email.md) covers each action and its limits.

```ocaml
let () =
  Workero.email (fun message _env _ctx ->
      Workero.Email.forward message "me@example.org")
```

## Runtime behavior

Each event handler runs in a fiber. You can call [`Workero.fetch`](./Workero.md#val-fetch), bindings and [`Workero.Promise.await`](./Workero-Promise.md#val-await) inside it while other events run. The build's `index.js` exports only the handlers registered at startup: `fetch`, `scheduled`, `queue` and/or `email`. A program with no event handlers and no [Durable Object classes](./durable_objects.md) or [entrypoint classes](./entrypoints.md) fails Worker initialization with `workero: the OCaml program registered no handler`.

An uncaught HTTP handler exception rejects the response Promise, and the runtime returns `500`. An uncaught cron handler exception fails that run. An uncaught Queue handler exception fails that delivery; unacknowledged messages can be retried. An uncaught email handler exception rejects the event, and Cloudflare treats the delivery as failed. Other events continue. See [`Workero.serve`](./Workero.md#val-serve), [`Workero.scheduled`](./Workero.md#val-scheduled), [`Workero.queue`](./Workero.md#val-queue) and [`Workero.email`](./Workero.md#val-email) for their signatures.
