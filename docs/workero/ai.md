
# Workers AI

[`Workero.Ai`](./Workero-Ai.md) runs models on [Workers AI](https://developers.cloudflare.com/workers-ai/). In both local development and deployment, inference uses Cloudflare's remote models and consumes account usage. Local `wrangler dev` does not simulate inference.


## Configure

```toml
[ai]
binding = "AI"
remote = true
```

## Use

```ocaml
let handler req env _ctx =
  let open Workero in
  let ai = Ai.of_env env "AI" in
  let prompt = Option.value (URL.query (Request.url req) "q") ~default:"hi" in
  let answer =
    Ai.run ai "@cf/meta/llama-3.1-8b-instruct"
      (`Assoc [ ("prompt", `String prompt) ])
  in
  JSON.response answer

let () = Workero.serve handler
```
- [`Workero.Ai.of_env`](./Workero-Ai.md#val-of_env) opens the binding. It raises `Invalid_argument` when there is no such binding, or when the binding has no `run` method.
- [`Workero.Ai.run`](./Workero-Ai.md#val-run) takes a model name and the input as a `Jsonkit.t`, waits for the model, and returns its answer as a `Jsonkit.t`. The input fields depend on the model. See the [model catalog](https://developers.cloudflare.com/workers-ai/models/).
- [`Workero.Ai.run_bytes`](./Workero-Ai.md#val-run_bytes) is the same call for a model that returns an image or audio. It returns the raw bytes; choose a model whose output is binary.

## Stream an answer

[`Workero.Ai.run_stream`](./Workero-Ai.md#val-run_stream) sets `stream` to `true` in the input and returns the answer as a [`Workero.Stream.t`](./Workero-Stream.md#type-t). Text models send server-sent events. Pass the stream to [`Workero.Response.of_stream`](./Workero-Response.md#val-of_stream) to forward it to the client:

```ocaml
let handler _req env _ctx =
  let open Workero in
  let ai = Ai.of_env env "AI" in
  let events =
    Ai.run_stream ai "@cf/meta/llama-3.1-8b-instruct"
      (`Assoc [ ("prompt", `String "Tell me a story") ])
  in
  Response.of_stream ~headers:[ ("content-type", "text/event-stream") ] events

let () = Workero.serve handler
```

## Route through AI Gateway

[`Workero.Ai.run`](./Workero-Ai.md#val-run), [`Workero.Ai.run_bytes`](./Workero-Ai.md#val-run_bytes) and [`Workero.Ai.run_stream`](./Workero-Ai.md#val-run_stream) take `~gateway`, made with [`Workero.Ai.gateway`](./Workero-Ai.md#val-gateway). It sets the gateway `id`, caching, logging, a timeout, [`Workero.Ai.retries`](./Workero-Ai.md#val-retries) and log metadata.

```ocaml
let gateway = Workero.Ai.gateway "my-gateway" ~cache_ttl:3600 ~skip_cache:false
```
If the runtime fails, for example on an unknown model, the call raises [`Workero.Js_error`](./Workero.md#exception-Js_error). `run` raises `Invalid_argument` when the model answers with a stream; use `run_stream` for that. `run_bytes` raises it when the answer is not binary data. Do not set `stream` in the input of `run`.


## Verify and deploy

With account access, run `npx wrangler dev` and request `/?q=hello`. Confirm that the response contains the model's JSON answer. Setting `remote = false` does not provide a local model. Deploy with `npx wrangler deploy` and repeat the request on the deployed Worker. A plain `workerd` configuration cannot run the actual model; workero's tests use a stub in `test/worker/services/ai.mjs` to check request and response conversion, not model output. Wrangler supports one AI binding per Worker. See the [model catalog](https://developers.cloudflare.com/workers-ai/models/) and [local binding support](https://developers.cloudflare.com/workers/local-development/bindings-per-env/).
