
# Logging

Use [`Workero.Console`](./Workero-Console.md) for one log entry at a chosen level. Use OCaml standard output or standard error when your code already writes there. This Worker logs a warning for a request method it does not serve.

```ocaml
let handler req _env _ctx =
  let open Workero in
  match Request.method_ req with
  | GET ->
      Console.info "serving GET";
      Response.text "ok\n"
  | _ ->
      Console.warn "request method not allowed";
      Response.text ~status:`Method_Not_Allowed "method not allowed\n"

let () = Workero.serve handler
```
Run `wrangler dev` in one terminal and `curl -i -X POST http://localhost:8787/` in a second terminal. The response has status 405\. Wrangler prints `request method not allowed` as a warning. Use `wrangler tail` or the Cloudflare dashboard for a deployed Worker. See [Workers logs](https://developers.cloudflare.com/workers/observability/logs/).


## Console and standard output

[`Workero.Console.log`](./Workero-Console.md#val-log), `info`, `warn`, `error`, and `debug` call the global `console`. Each call writes one entry without an OCaml buffer to flush. Standard output and standard error also reach Workers logs, but they use OCaml buffers. Workero flushes those buffers when a [`Workero.serve`](./Workero.md#val-serve), [`Workero.scheduled`](./Workero.md#val-scheduled), or [`Workero.queue`](./Workero.md#val-queue) handler finishes, even if it raises. Durable Object initialization, fetch, and alarm handlers also flush them. Thus `Printf.printf` inside these handlers needs no newline or `%!` to appear when the handler ends.

Output written after the handler ends, for example from a function given to [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until), stays in the buffer until the next handler ends. Flush `stdout` or `stderr` there if the entry must appear at once, or use [`Workero.Console`](./Workero-Console.md).
