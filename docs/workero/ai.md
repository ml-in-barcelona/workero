
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
If the runtime fails, for example on an unknown model, the call raises [`Workero.Js_error`](./Workero.md#exception-Js_error). `run` raises `Invalid_argument` when the model answers with a stream, and `run_bytes` when the answer is not binary data. Streaming answers are not supported yet. Do not set `stream` in the input of `run`.


## Verify and deploy

With account access, run `npx wrangler dev` and request `/?q=hello`. Confirm that the response contains the model's JSON answer. Setting `remote = false` does not provide a local model. Deploy with `npx wrangler deploy` and repeat the request on the deployed Worker. A plain `workerd` configuration cannot run the actual model; workero's tests use a stub in `test/worker/services/ai.mjs` to check request and response conversion, not model output. Wrangler supports one AI binding per Worker. See the [model catalog](https://developers.cloudflare.com/workers-ai/models/) and [local binding support](https://developers.cloudflare.com/workers/local-development/bindings-per-env/).
