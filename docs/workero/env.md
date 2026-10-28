
# Variables and secrets

The handler's [`Workero.Env.t`](./Workero-Env.md#type-t) contains string variables, Worker secrets, object and array variables, and resource bindings. Choose the reader by the value's shape and the way you configure it.


## Read a string variable

Set a non-sensitive value in `wrangler.toml`:

```toml
[vars]
GREETING = "hello"
```
[`Workero.Env.var`](./Workero-Env.md#val-var) returns `Some string` for a string variable or Worker secret. It returns `None` if the name is absent or the value is not a string. This Worker answers `hello` for `GET /` with the configuration above:

```ocaml
let handler _req env _ctx =
  let greeting = Option.value (Workero.Env.var env "GREETING") ~default:"unset" in
  Workero.Response.text greeting

let () = Workero.serve handler
```
Run `wrangler dev` and request `/`. Deploy the Worker with `wrangler deploy` to use the same `vars` in Cloudflare. Do not put keys or tokens in `vars`. See [Cloudflare variables](https://developers.cloudflare.com/workers/configuration/environment-variables/).


## Require a Worker secret

Use a Worker secret for a value that belongs to this Worker. For local development, put `API_TOKEN=local-test-token` in `.dev.vars` beside `wrangler.toml`. Keep `.dev.vars*` out of Git. Run `wrangler dev` and request `/`; the Worker below answers `token set` without exposing the value.

```ocaml
let handler _req env _ctx =
  let token = Workero.Env.secret env "API_TOKEN" in
  Workero.Response.text (if token = "" then "token empty" else "token set")

let () = Workero.serve handler
```
For the deployed Worker, run `wrangler secret put API_TOKEN` and enter the value at the prompt. This command creates and deploys a new Worker version. Then deploy your code with `wrangler deploy`. [`Workero.Env.secret`](./Workero-Env.md#val-secret) reads the same string shape as `Env.var`, but requires it: if it is absent or not a string, it raises `Invalid_argument` with the name and type, never the value. A local `.dev.vars` file does not upload the secret. See [Cloudflare Worker secrets](https://developers.cloudflare.com/workers/configuration/secrets/).


## Read an object or array variable

Declare a non-sensitive JSON-shaped variable in `wrangler.toml`:

```toml
[vars]
LIMITS = { max_items = 50, regions = ["eu", "us"] }
```
[`Workero.Env.json`](./Workero-Env.md#val-json) returns `Some Jsonkit.t` for an object or array. It returns `None` for an absent value, a string, number, boolean or `null`. [`Workero.Env.var`](./Workero-Env.md#val-var) returns `None` for these object and array values.

```ocaml
let handler _req env _ctx =
  match Workero.Env.json env "LIMITS" with
  | Some (`Assoc fields) -> (
      match List.assoc_opt "max_items" fields with
      | Some (`Int max_items) -> Workero.Response.text (string_of_int max_items)
      | _ ->
          Workero.Response.text ~status:`Internal_Server_Error
            "max_items must be an integer")
  | _ ->
      Workero.Response.text ~status:`Internal_Server_Error
        "LIMITS missing or not an object"

let () = Workero.serve handler
```
Run `wrangler dev` and request `/`; the response is `50`. The same `vars` are sent with `wrangler deploy`. Add `jsonkit` to your Dune `libraries` when using `Jsonkit` directly. [`Workero.JSON.of_js`](./Workero-JSON.md#val-of_js) and [`Workero.JSON.to_js`](./Workero-JSON.md#val-to_js) convert general JSON-shaped JavaScript values; [JSON](./json.md) covers JSON HTTP bodies.


## Read a shared Secrets Store secret

Secrets Store holds account-level secrets shared by Workers. Its value is a resource binding, not a string in `env`. Configure the binding in `wrangler.toml`:

```toml
[[secrets_store_secrets]]
binding = "API_KEY"
store_id = "<store id>"
secret_name = "api-key"
```
[`Workero.Secret_store.of_env`](./Workero-Secret_store.md#val-of_env) checks the binding. [`Workero.Secret_store.get`](./Workero-Secret_store.md#val-get) suspends until the value is available. It returns `None` for a `null` or `undefined` result and raises [`Workero.Js_error`](./Workero.md#exception-Js_error) on a runtime failure.

```ocaml
let handler _req env _ctx =
  let key = Workero.Secret_store.of_env env "API_KEY" in
  match Workero.Secret_store.get key with
  | Some value ->
      Workero.Response.text (if value = "" then "key empty" else "key set")
  | None -> Workero.Response.text ~status:`Internal_Server_Error "key missing"

let () = Workero.serve handler
```
For local `wrangler dev`, create a local store and secret, without `--remote`:

```sh
wrangler secrets-store store create local-store
wrangler secrets-store secret create <local-store-id> --name api-key --scopes workers
```
Enter the secret at the prompt. Put the returned local store ID in `store_id`, run `wrangler dev`, and request `/`. Expect `key set`. Local development cannot read production Secrets Store secrets. To deploy, create a remote store and secret:

```sh
wrangler secrets-store store create shared-store --remote
wrangler secrets-store secret create <remote-store-id> --name api-key --scopes workers --remote
```
Put the remote store ID in `store_id`, then run `wrangler deploy`. You need a Secrets Store role that allows binding access. Do not put a secret value on a command line or log it. See [Cloudflare Secrets Store bindings](https://developers.cloudflare.com/secrets-store/integrations/workers/) and [Wrangler commands](https://developers.cloudflare.com/workers/wrangler/commands/).
