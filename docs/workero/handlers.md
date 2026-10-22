
# Handlers

A worker answers events. workero has one handler for each kind of event: [`Workero.serve`](./Workero.md#val-serve) for HTTP requests, [`Workero.scheduled`](./Workero.md#val-scheduled) for cron triggers and [`Workero.queue`](./Workero.md#val-queue) for queue messages and [`Workero.email`](./Workero.md#val-email) for email. Register a handler once, at the top level of your program.


## HTTP requests

[`Workero.serve`](./Workero.md#val-serve) takes a function of three arguments, as the JavaScript `fetch(request, env, ctx)` handler does:

- a [`Workero.Request.t`](./Workero-Request.md#type-t), the incoming request,
- a [`Workero.Env.t`](./Workero-Env.md#type-t), the variables and secrets of the worker (see [Variables and secrets](./env.md)),
- a [`Workero.Context.t`](./Workero-Context.md#type-t), to keep work running after the response (see [Waiting for JavaScript](./async.md)).
It returns a [`Workero.Response.t`](./Workero-Response.md#type-t).

```ocaml
let handler req env _ctx =
  let open Workero in
  match (Request.method_ req, URL.path (Request.url req)) with
  | GET, "/" -> Response.text "Hello from OCaml on Cloudflare Workers\n"
  | POST, "/echo" -> Response.text (Request.text req)
  | GET, "/env" ->
      Response.text
        (Option.value (Env.var env "GREETING") ~default:"unset" ^ "\n")
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
The handler runs in direct style. It can wait for a body, for [`Workero.fetch`](./Workero.md#val-fetch) or for [`Workero.Promise.await`](./Workero-Promise.md#val-await). Other requests keep running while it waits.


## Falling back to the origin

[`Workero.Context.pass_through_on_exception`](./Workero-Context.md#val-pass_through_on_exception) makes the runtime send the request to the origin server when the handler raises. It needs a route with an origin. It has no effect on `workers.dev`.


## Cron triggers

[`Workero.scheduled`](./Workero.md#val-scheduled) registers the handler for [Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/). It gets a [`Workero.Scheduled.t`](./Workero-Scheduled.md#type-t), the `env` and the `ctx`, and returns `unit`.

```ocaml
let () =
  Workero.serve (fun _req _env _ctx -> Workero.Response.text "ok\n");
  Workero.scheduled (fun controller _env _ctx ->
      let cron = Workero.Scheduled.cron controller in
      let at = Workero.Scheduled.scheduled_time controller in
      Printf.printf "cron %s scheduled for %.0f\n%!" cron at)
```
[`Workero.Scheduled.cron`](./Workero-Scheduled.md#val-cron) is the cron expression that fired. [`Workero.Scheduled.scheduled_time`](./Workero-Scheduled.md#val-scheduled_time) is the scheduled time in milliseconds since the Unix epoch.

List the schedules in `wrangler.toml`:

```toml
[triggers]
crons = ["*/5 * * * *"]
```
To fire a trigger by hand while `wrangler dev --test-scheduled` runs, request Wrangler's `/__scheduled` route:

```sh
curl "http://localhost:8787/__scheduled?cron=*/5+*+*+*+*"
```
A worker can register [`Workero.serve`](./Workero.md#val-serve), [`Workero.scheduled`](./Workero.md#val-scheduled), or both. A worker that only has cron triggers needs no [`Workero.serve`](./Workero.md#val-serve). The same holds for [`Workero.queue`](./Workero.md#val-queue).


## Queue messages

[`Workero.queue`](./Workero.md#val-queue) registers the consumer of a Cloudflare Queue. It gets a [`Workero.Queue.Batch.t`](./Workero-Queue-Batch.md#type-t), the `env` and the `ctx`, and returns `unit`. See [Queue](./queue.md) for configuration, acknowledgement and retries.

```ocaml
let () =
  Workero.queue (fun batch _env _ctx ->
      List.iter
        (fun message ->
          print_endline (Workero.Queue.Message.body_text message);
          Workero.Queue.Message.ack message)
        (Workero.Queue.Batch.messages batch))
```

## Email

[`Workero.email`](./Workero.md#val-email) registers the Email Routing handler. It gets a [`Workero.Email.t`](./Workero-Email.md#type-t), the `env` and the `ctx`, and returns `unit`. The handler forwards, replies to or rejects the message. See [Email](./email.md).

```ocaml
let () =
  Workero.email (fun message _env _ctx ->
      Workero.Email.forward message "me@example.org")
```
A worker can register any combination of [`Workero.serve`](./Workero.md#val-serve), [`Workero.scheduled`](./Workero.md#val-scheduled), [`Workero.queue`](./Workero.md#val-queue) and [`Workero.email`](./Workero.md#val-email).


## What index.js exports

`workero build` writes an `index.js` with a default export that has one function for each registered handler:

```js
export default { fetch, scheduled, queue, email };
```
Only the handlers that your program registered are present, so Wrangler sees the right events. If the program registers none at start-up, `index.js` throws `workero: the OCaml program registered no handler`. Register handlers at the top level, not inside another function that runs later.


## Errors

- An exception that escapes the [`Workero.serve`](./Workero.md#val-serve) handler rejects the response Promise, and the runtime answers with status 500\.
- An exception that escapes the [`Workero.scheduled`](./Workero.md#val-scheduled) handler rejects the event Promise, and Cloudflare records the run as failed.
- An exception that escapes the [`Workero.queue`](./Workero.md#val-queue) handler rejects the event Promise. Cloudflare delivers again the messages that the handler did not ack.
- An exception that escapes the [`Workero.email`](./Workero.md#val-email) handler rejects the event Promise, and Cloudflare treats the delivery as failed.
- A later request or event is not affected.
Catch the exceptions that you can answer, and let the others escape. For example, [`Workero.JSON.decode`](./Workero-JSON.md#val-decode) turns a bad body into a 400 instead of a 500\.
