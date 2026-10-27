
# HTML rewriting

[`Workero.Html_rewriter`](./Workero-Html_rewriter.md) edits an HTML response while it streams, like the [`HTMLRewriter`](https://developers.cloudflare.com/workers/runtime-apis/html-rewriter/) of the Workers runtime. Use it to change attributes, insert markup, or remove elements in a page that you fetch from an origin.

The runtime parses the body and calls your functions only for the nodes that match. OCaml never reads the whole body, so a large page costs no OCaml memory except the nodes that you handle. This is the reason to prefer it over [`Workero.Response.body_text`](./Workero-Response.md#val-body_text) and a string replace.


## Use

```ocaml
let handler req _env _ctx =
  let open Workero in
  let origin = fetch "https://example.com/" in
  Html_rewriter.(
    transform
      (create ()
      |> on
           ~element:(fun el ->
             Element.set_attribute el "rel" "noopener";
             Element.append el (Text " (external)"))
           "a[href^='http']"
      |> on_document
           ~end_:(fun e -> Document_end.append e (Html "<!-- rewritten -->")))
      origin)

let () = Workero.serve handler
```
- [`Workero.Html_rewriter.create`](./Workero-Html_rewriter.md#val-create) makes a rewriter with no handlers. [`Workero.Html_rewriter.on`](./Workero-Html_rewriter.md#val-on) and [`Workero.Html_rewriter.on_document`](./Workero-Html_rewriter.md#val-on_document) add handlers and return the rewriter, so calls chain. A rewriter may be a toplevel value, and [`Workero.Html_rewriter.transform`](./Workero-Html_rewriter.md#val-transform) may run on many responses.
- A selector is a string. The runtime supports the CSS subset that Cloudflare documents. A selector that the runtime rejects raises [`Workero.Js_error`](./Workero.md#exception-Js_error) from `on`.
- [`Workero.Html_rewriter.transform`](./Workero-Html_rewriter.md#val-transform) returns a new response with the same status and headers. It streams, so return it from the handler as it is.

## Content

Functions that insert content take [`Workero.Html_rewriter.content`](./Workero-Html_rewriter.md#type-content). `Text s` is escaped: `<b>` becomes `&lt;b&gt;`. `Html s` is inserted as markup, so never build it from input that you do not trust.

`Text_stream`, `Html_stream`, `Text_response`, and `Html_response` take a [`Workero.Stream.t`](./Workero-Stream.md#type-t) or a [`Workero.Response.t`](./Workero-Response.md#type-t) in place of a string. The runtime reads it as the page streams, so a large inserted body does not go through OCaml. The `Text_` forms escape and the `Html_` forms insert markup, like `Text` and `Html`. A response gives only its body: status and headers are ignored. The stream or response is used up.

```ocaml
let banner el =
  let res = Workero.fetch "https://example.com/banner.html" in
  Workero.Html_rewriter.(Element.prepend el (Html_response res))
```

## Handlers that wait

Each handler runs in its own fiber, so it may call [`Workero.Promise.await`](./Workero-Promise.md#val-await), [`Workero.fetch`](./Workero.md#val-fetch), or any binding:

```ocaml
let price el =
  let res = Workero.fetch "https://api.example.com/price" in
  Workero.Html_rewriter.(
    Element.set_inner_content el (Text (Workero.Response.body_text res)))
```
The runtime waits for a handler to return before it parses on. In `workerd`, two handlers that wait run one after the other, in document order. Cloudflare does not document this order, and the tests do not prove it, so do not depend on it.

Make every change before the handler returns. A node is invalid after that, and using it raises [`Workero.Js_error`](./Workero.md#exception-Js_error).

If a handler raises, the parse stops and the body of the transformed response errors with the exception text. A client that already got bytes sees a truncated response. Handle expected failures inside the handler.

A handler runs as a fiber, which costs about 1\.5 times a plain callback. A page with tens of thousands of matches pays about 2 microseconds more for each match.


## Text nodes

A text node can arrive in several chunks. [`Workero.Html_rewriter.Text_chunk.text`](./Workero-Html_rewriter-Text_chunk.md#val-text) returns one chunk, and the last chunk of a node is often empty. Join the chunks until [`Workero.Html_rewriter.Text_chunk.last_in_text_node`](./Workero-Html_rewriter-Text_chunk.md#val-last_in_text_node) is `true`:

```ocaml
let titles = Buffer.create 64

let rewriter =
  Workero.Html_rewriter.(
    create ()
    |> on
         ~text:(fun t ->
           Buffer.add_string titles (Text_chunk.text t);
           if Text_chunk.last_in_text_node t then
             Text_chunk.replace t
               (Text (String.uppercase_ascii (Buffer.contents titles)))
           else Text_chunk.remove t)
         "title")
```

## Limits

See the [open issues](https://github.com/ml-in-barcelona/workero/issues) for what the module does not wrap.
