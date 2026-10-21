
# Handlers

A worker answers events. workero has one handler for each kind of event: [`Workero.serve`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-serve) for HTTP requests and [`Workero.scheduled`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-scheduled) for cron triggers. Register a handler once, at the top level of your program.


## HTTP requests

[`Workero.serve`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-serve) takes a function of three arguments, as the JavaScript `fetch(request, env, ctx)` handler does:

- a [`Workero.Request.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/Request/index.html#type-t), the incoming request,
- an [`Workero.Env.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/Env/index.html#type-t), the worker's variables, secrets, and resource bindings (see [Variables and secrets](./env.md) and [Bindings](./bindings.md)),
- a [`Workero.Context.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/Context/index.html#type-t), for background work and origin fallback (see [Async and background work](./async.md)).
It returns a [`Workero.Response.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#type-t).

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
The handler runs in direct style. It can wait for a body, for [`Workero.fetch`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-fetch) or for [`Workero.Promise.await`](https://ml-in-barcelona.github.io/workero/workero/Workero/Promise/index.html#val-await). Other requests keep running while it waits.


## Falling back to the origin

[`Workero.Context.pass_through_on_exception`](https://ml-in-barcelona.github.io/workero/workero/Workero/Context/index.html#val-pass_through_on_exception) makes the runtime send the request to the origin server when the handler raises. It needs a route with an origin. It has no effect on `workers.dev`.


## Cron triggers

[`Workero.scheduled`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-scheduled) registers the handler for [Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/). It gets a [`Workero.Scheduled.t`](https://ml-in-barcelona.github.io/workero/workero/Workero/Scheduled/index.html#type-t), the `env` and the `ctx`, and returns `unit`.

```ocaml
let () =
  Workero.serve (fun _req _env _ctx -> Workero.Response.text "ok\n");
  Workero.scheduled (fun controller _env _ctx ->
      let cron = Workero.Scheduled.cron controller in
      let at = Workero.Scheduled.scheduled_time controller in
      Printf.printf "cron %s scheduled for %.0f\n%!" cron at)
```
[`Workero.Scheduled.cron`](https://ml-in-barcelona.github.io/workero/workero/Workero/Scheduled/index.html#val-cron) is the cron expression that fired. [`Workero.Scheduled.scheduled_time`](https://ml-in-barcelona.github.io/workero/workero/Workero/Scheduled/index.html#val-scheduled_time) is the scheduled time in milliseconds since the Unix epoch.

List the schedules in `wrangler.toml`:

```toml
[triggers]
crons = ["*/5 * * * *"]
```
To fire a trigger by hand while `wrangler dev --test-scheduled` runs, request Wrangler's `/__scheduled` route:

```sh
curl "http://localhost:8787/__scheduled?cron=*/5+*+*+*+*"
```
A worker can register [`Workero.serve`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-serve), [`Workero.scheduled`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-scheduled), or both. A worker that only has cron triggers needs no [`Workero.serve`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-serve).

Register handlers at the top level so they are ready when the Worker starts. See [How it works](./how_it_works.md) for the generated JavaScript entry point.


## Errors

- An exception that escapes the [`Workero.serve`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-serve) handler rejects the response Promise, and the runtime answers with status 500\.
- An exception that escapes the [`Workero.scheduled`](https://ml-in-barcelona.github.io/workero/workero/Workero/index.html#val-scheduled) handler rejects the event Promise, and Cloudflare records the run as failed.
- A later request or event is not affected.
Catch errors when your handler can answer them. For example, [`Workero.JSON.decode`](https://ml-in-barcelona.github.io/workero/workero/Workero/JSON/index.html#val-decode) returns `Error message` for invalid JSON; your handler can then choose a 400 response with [`Workero.JSON.error`](https://ml-in-barcelona.github.io/workero/workero/Workero/JSON/index.html#val-error). See [JSON](./json.md).
