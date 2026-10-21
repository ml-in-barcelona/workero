# Changes

## Unreleased

- First release: the `workero` library and the `workero build` CLI.
  - `Workero.serve` (HTTP handler with `Request`, `Env`, `Context`) and `Workero.scheduled` (Cron Triggers). `workero build` exports only the registered handlers.
  - `Workero.fetch` for outgoing requests, `Context.wait_until`, `Promise.await` in direct style.
  - `Request`: `method_` (`Method.t`), `url` (`URL.t`), `header`, `headers`, `text`, `bytes`, `cf`.
  - `Response`: `text`, `html`, `make`, `redirect`, and `status`, `header`, `headers`, `body_text`, `body_bytes`.
  - `to_js` and `of_js` on each type.
- `Workero.JSON`: JSON requests and responses with jsonkit.
- Storage bindings: `Workero.KV` (`list` follows the cursor), `Workero.Cache`, `Workero.R2`, `Workero.D1` with `Workero.Sql_value` (`Int of int64`, exact up to 2^53). JS errors in bindings, thrown or rejected, raise `Js_error "Name: message"`.
- `Workero.Promise` is backed by `Js_of_ocaml.Promise`, so `'a t t` is sound. `of_js` and binding calls take a decoder (`Workero.Decode`). `Promise.error` is opaque and `Js_error` carries the original JS reason. New `map`, `bind`, `all`, `race`, `any`, `all_settled`.
- An exception during program initialisation fails the worker load with its message, instead of "registered no handler".
- `workero build` fails when the program uses functions with no wasm implementation, instead of failing on each request.
