# Changes

## Unreleased

- `Workero.Durable_object`: Durable Objects with SQLite storage. `register` binds a class, `make` builds its handlers (`init`, `fetch`, `alarm`), `Namespace` opens a binding and gives stubs (a `Fetcher.t`), `Id`, `State` and `Storage` (synchronous key-value, alarms, `sync`, `delete_all`).
- `workero build` and `workero package` run the program once in `workerd` to read the registered Durable Object classes, export them from `index.js` and write `durable-object.js`. They need `workerd` (`WORKERD`, `PATH` or `node_modules/.bin`). A program that raises during initialisation now fails the build with its error.
- `index.js` accepts a worker that registers only Durable Object classes.
- `Env.secret` reads a required string variable or secret and raises `Invalid_argument`, without the value, when it is missing or not a string. `Env.json` reads an object or array variable as a `Jsonkit.t`.
- `JSON.of_js` and `JSON.to_js` convert between JavaScript values and `Jsonkit.t` through `JSON.stringify` and `JSON.parse`.
- `Workero.Secret_store`: Secrets Store secrets (`of_env`, `get`).
- `Workero.Fetcher`: service bindings and assets (`of_env`, `fetch`, `fetch_request`), the type that Durable Object stubs will use.
- `URL.pathname`, `URL.search`, `URL.hash` and `URL.origin` give the raw parts of a URL, as the JavaScript `URL` does.
- `Context.pass_through_on_exception` binds `ctx.passThroughOnException()`. It needs a route with an origin.
- `serve` and `scheduled` flush standard output and standard error when a handler ends, also when it raises, so `print_string` and `Printf.printf` reach the logs without `%!`. Output from a `wait_until` function that runs after the handler returns appears when the next handler ends.
- First release: the `workero` library and the `workero build` CLI.
  - `Workero.serve` (HTTP handler with `Request`, `Env`, `Context`) and `Workero.scheduled` (Cron Triggers). `workero build` exports only the registered handlers.
  - `Workero.fetch` for outgoing requests, `Context.wait_until`, `Promise.await` in direct style.
  - `Request`: `method_` (`Method.t`), `url` (`URL.t`), `header`, `headers`, `text`, `bytes`, `cf`.
  - `Response`: `text`, `html`, `make`, `redirect`, and `status`, `header`, `headers`, `body_text`, `body_bytes`.
  - `to_js` and `of_js` on each type.
- `Workero.JSON`: JSON requests and responses. Values are `Jsonkit.t`. The module has no `t` alias and does not re-export jsonkit; add `jsonkit` to your dune `libraries`.
- Storage bindings: `Workero.KV` (`list` follows the cursor), `Workero.Cache`, `Workero.R2`, `Workero.D1` with `Workero.Sql_value` (`Int of int64`, exact up to 2^53). JS errors in bindings, thrown or rejected, raise `Js_error "Name: message"`.
- `Workero.Promise` is backed by `Js_of_ocaml.Promise`, so `'a t t` is sound. `of_js` and binding calls take a decoder (`Workero.Decode`). `Promise.error` is opaque and `Js_error` carries the original JS reason. New `map`, `bind`, `all`, `race`, `any`, `all_settled`.
- An exception during program initialisation fails the worker load with its message, instead of "registered no handler".
- `workero build` fails when the program uses functions with no wasm implementation, instead of failing on each request.
- Typed bindings for JavaScript globals: `Workero.Timer` (`sleep`, `set_timeout`, `set_interval`, `clear_timeout`, `clear_interval`), `Workero.Date`, `Workero.Crypto` and `Workero.Console`. Examples and tests no longer call `setTimeout` through `Js.Unsafe`.
- Naming: `Sql_value.row`, one `__workero` JS global, `Decode.unit`, `Makefile` targets `test-worker-init` and `test-worker-exports`.
- `Workero.Stream`: byte streams with `Reader`, `Writer`, `iter` and `pipe`. `Request.body` and `Response.body` give a stream. `Response.stream` writes a body in its own fiber with back-pressure, and a client disconnect raises `Js_error` on write. `Response.of_stream` passes a body through.
- `Workero.Form_data` and `Request.form_data`: multipart and urlencoded forms, with text values and files (`file_name`, `file_type`, `file_size`, `file_bytes`, `file_stream`). The runtime buffers the whole upload.
- `Workero.Websocket`: `upgrade` with a receive loop, `pair`, `accept`, `send`, `receive`, `close`, `response`. Events come in order; there are no callbacks.
- New `Request` values: `path`, `query_string`, `header_all`, `clone`, `body`.
- New `Response` values: `empty`, `copy`, `clone`, `header_all`, `body`, `of_stream`, `stream`.
- `Response.redirect` accepts a relative URL, such as `"/login"`.
- Breaking: `~status` is a `Workero.Status` variant, not an `int`: ``Response.text ~status:`Not_Found``, ``Response.empty `No_Content``. Tags follow Dream; ``Status n`` names any other code. ``Response.redirect`` takes only the redirect tags. A no-body status with a body does not type-check; ``Status 204`` with a body, or a code outside 200..599, raises `Invalid_argument`. `Response.status` still returns an `int`.
- `URL` uses the JavaScript `URL`. A host with `_` and a URL with userinfo now parse, and `Request.url` does not raise for them. `?a` gives `("a", "")`. `+` in a path stays `+`. A malformed escape such as `%zz` leaves the whole path undecoded. `to_string` gives the normalised `href`: a trailing `/` is added and the fragment is kept.
