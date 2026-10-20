# Changes

## Unreleased

- First release: the `workero` library and the `workero build` CLI.
  - `Workero.serve` (HTTP handler with `Request`, `Env`, `Context`) and `Workero.scheduled` (Cron Triggers). `workero build` exports only the registered handlers.
  - `Workero.fetch` for outgoing requests, `Context.wait_until`, `Promise.await` in direct style.
  - `Request`: `method_` (`Method.t`), `url` (`URL.t`), `header`, `headers`, `text`, `bytes`, `cf`.
  - `Response`: `text`, `html`, `make`, `redirect`, and `status`, `header`, `headers`, `body_text`, `body_bytes`.
  - `to_js` and `of_js` on each type.
- `Workero.JSON`: JSON requests and responses with jsonkit.
