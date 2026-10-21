
# Variables and secrets

Use string bindings for configuration. The handler's `env` argument holds variables and secrets as well as resource bindings. [`Workero.Env.var`](https://ml-in-barcelona.github.io/workero/workero/Workero/Env/index.html#val-var) returns `Some value` for a string variable or secret. It returns `None` for a missing name or a value that is not a string.


## Configure locally

Put a non-secret variable in `wrangler.toml`:

```toml
[vars]
GREETING = "hello from vars"
```
For a local secret, put `API_TOKEN=local-token` in `.dev.vars` beside `wrangler.toml`. Keep `.dev.vars*` out of Git. Do not put secrets in `[vars]`.


## Read a string binding

```ocaml
let handler req env _ctx =
  let open Workero in
  match URL.path (Request.url req) with
  | "/greeting" -> (
      match Env.var env "GREETING" with
      | Some value -> Response.text (value ^ "\n")
      | None -> Response.text ~status:`Internal_Server_Error "GREETING is not set\n")
  | "/token" -> (
      match Env.var env "API_TOKEN" with
      | Some value ->
          Response.text (Printf.sprintf "token of %d bytes\n" (String.length value))
      | None -> Response.text ~status:`Internal_Server_Error "API_TOKEN is not set\n")
  | _ -> Response.text ~status:`Not_Found "not found\n"

let () = Workero.serve handler
```
A variable and a secret have the same string value in `env`. Do not return the secret itself in a response.


## Verify locally

Run `npx wrangler dev` in one terminal. In another terminal, run:

```sh
curl http://localhost:8787/greeting
curl http://localhost:8787/token
```
The first response is `hello from vars`. With the example `.dev.vars`, the second is `token of 11 bytes`. If you omit `.dev.vars`, `/token` returns `API_TOKEN is not set` with status 500\.


## Set a deployed secret

Before deployment, use an authenticated Wrangler to store a secret for the deployed Worker. Wrangler asks for the value without adding it to `wrangler.toml`:

```sh
npx wrangler secret put API_TOKEN
```
See the [Cloudflare variables guide](https://developers.cloudflare.com/workers/configuration/environment-variables/), [secrets guide](https://developers.cloudflare.com/workers/configuration/secrets/) and [`Workero.Env`](./Workero-Env.md) API.
