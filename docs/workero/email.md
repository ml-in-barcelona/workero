
# Email

[`Workero.email`](./Workero.md#val-email) registers the handler for [Email Workers](https://developers.cloudflare.com/email-routing/email-workers/). Cloudflare Email Routing calls it for each message sent to an address that you route to the Worker. The handler gets an [`Workero.Email.t`](./Workero-Email.md#type-t), the `env` and the `ctx`, and returns `unit`.


## Configure

Turn on Email Routing for the domain. In the dashboard, add a custom address and set its action to "Send to a Worker". To forward a message, add the destination address to Email Routing first and verify it. `wrangler.toml` needs no email setting for the handler.


## Handle a message

The handler must decide what happens to the message. It does one of three things:

- [`Workero.Email.forward`](./Workero-Email.md#val-forward) sends the message to a verified address.
- [`Workero.Email.reply`](./Workero-Email.md#val-reply) sends a reply to the sender.
- [`Workero.Email.set_reject`](./Workero-Email.md#val-set_reject) refuses the message with a permanent SMTP error.
```ocaml
let () =
  Workero.email (fun message _env _ctx ->
      let open Workero in
      match Email.header message "subject" with
      | Some subject when String.length subject > 0 ->
          Email.forward
            ~headers:[ ("X-Routed-By", "workero") ]
            message "me@example.org"
      | _ -> Email.set_reject message "a subject is required")
```
[`Workero.Email.from`](./Workero-Email.md#val-from) is the envelope sender and [`Workero.Email.to_`](./Workero-Email.md#val-to_) is the envelope recipient. They can differ from the `From` and `To` headers. Read the headers with [`Workero.Email.header`](./Workero-Email.md#val-header), [`Workero.Email.header_all`](./Workero-Email.md#val-header_all) and [`Workero.Email.headers`](./Workero-Email.md#val-headers). [`Workero.Email.raw_size`](./Workero-Email.md#val-raw_size) is the size of the raw message in bytes.

[`Workero.Email.forward`](./Workero-Email.md#val-forward) takes extra headers. The runtime accepts only names that start with `X-`. It raises [`Workero.Js_error`](./Workero.md#exception-Js_error) when the address is not a verified destination.


## Read the raw message

[`Workero.Email.raw_text`](./Workero-Email.md#val-raw_text) and [`Workero.Email.raw_bytes`](./Workero-Email.md#val-raw_bytes) read the whole message, with its headers, and suspend like [`Workero.Promise.await`](./Workero-Promise.md#val-await). The raw message can be read once. A second read raises [`Workero.Js_error`](./Workero.md#exception-Js_error).

```ocaml
let () =
  Workero.email (fun message _env _ctx ->
      let open Workero in
      if Email.raw_size message > 1_000_000 then
        Email.set_reject message "message too large"
      else
        let raw = Email.raw_text message in
        Console.log raw;
        Email.forward message "me@example.org")
```
The program holds the whole message in memory, and the bytes are copied once from JavaScript into the memory of the wasm program. For a large message, read [`Workero.Email.raw`](./Workero-Email.md#val-raw) as a [`Workero.Stream.t`](./Workero-Stream.md#type-t) and handle it in chunks with [`Workero.Stream.iter`](./Workero-Stream.md#val-iter). Check [`Workero.Email.raw_size`](./Workero-Email.md#val-raw_size) before you read.


## Reply

[`Workero.Email.reply`](./Workero-Email.md#val-reply) sends a complete message, with headers, as the reply. The runtime accepts a reply only when the sender allows it, so the raw message needs a `Message-ID` header and an `In-Reply-To` header with the `Message-ID` of the incoming message. `~from` must be an address of the Worker's domain, and `~to_` the sender:

```ocaml
let () =
  Workero.email (fun message _env _ctx ->
      let open Workero in
      let id = Option.value (Email.header message "message-id") ~default:"" in
      Email.reply message ~from:"support@example.com" ~to_:(Email.from message)
        (String.concat "\r\n"
           [
             "From: support@example.com";
             "To: " ^ Email.from message;
             "Message-ID: <reply-1@example.com>";
             "In-Reply-To: " ^ id;
             "Subject: Received";
             "";
             "We got your message.";
             "";
           ]))
```
[`Workero.Email.reply_stream`](./Workero-Email.md#val-reply_stream) takes the same complete message as a [`Workero.Stream.t`](./Workero-Stream.md#type-t), for example from [`Workero.Stream.pipe`](./Workero-Stream.md#val-pipe). Write it from a [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until) function, because the runtime reads the stream while the call waits.

`reply` creates the `EmailMessage` from the `cloudflare:email` module when it is called. `workerd` does not provide that module. See [Support and known issues](./known_issues.md).


## Errors

An exception that escapes the handler rejects the event Promise, and Cloudflare treats the delivery as failed. Catch [`Workero.Js_error`](./Workero.md#exception-Js_error) from [`Workero.Email.forward`](./Workero-Email.md#val-forward) and [`Workero.Email.reply`](./Workero-Email.md#val-reply) to answer with [`Workero.Email.set_reject`](./Workero-Email.md#val-set_reject) instead.


## Testing

`workerd` 2026-10-19 cannot deliver an email. A service binding has `fetch`, `scheduled` and `queue` methods but no `email` method, and the runtime has no `cloudflare:email` module. To test a handler, import the generated `index.js` in a small test worker, build a message object with the fields of `ForwardableEmailMessage` (`from`, `to`, `headers`, `raw`, `rawSize`, `setReject`, `forward`, `reply`) and call `handlers.email(message, env, ctx)`. `test/worker/services/email-harness.mjs` does this, and `test/worker/cases/email.mjs` has the cases. The test worker gives a stand-in `cloudflare:email` module for `reply`. The tests do not prove that the real runtime accepts the messages.
