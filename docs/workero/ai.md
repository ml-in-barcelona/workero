
# Workers AI

[`Workero.Ai`](./Workero-Ai.md) runs models on [Workers AI](https://developers.cloudflare.com/workers-ai/). Requests are billed to your account, also in `wrangler dev`.


## Configure

```toml
[ai]
binding = "AI"
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
- [`Workero.Ai.run_bytes`](./Workero-Ai.md#val-run_bytes) is the same call for a model that returns an image or audio. It returns the raw bytes.
If the runtime fails, for example on an unknown model, the call raises [`Workero.Js_error`](./Workero.md#exception-Js_error). `run` raises `Invalid_argument` when the model answers with a stream, and `run_bytes` when the answer is not binary data. Streaming answers are not supported yet. Do not set `stream` in the input of `run`.


## Test

The binding is not available in a plain `workerd` configuration. The tests of workero use a stub that implements `run`. See `test/worker/services/ai.mjs`.
