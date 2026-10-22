
# Module `Durable_object.Container`

The container attached to an object, on Cloudflare Containers. Declare it in `wrangler.toml` with `[[containers]]` and the class name of the object. The container starts only when [`start`](./#val-start) runs. The functions raise [`Js_error`](./Workero.md#exception-Js_error) when the runtime throws or rejects, for example when no image is configured or the container is not running.

`workerd` runs a container only with Docker: see [Durable Objects](./durable_objects.md).

```ocaml
type t
```
```ocaml
val running : t -> bool
```
`true` once [`start`](./#val-start) ran and until the container exits or is destroyed. It does not mean that the program in the container accepts connections.

```ocaml
val start : 
  ?entrypoint:string list ->
  ?env:(string * string) list ->
  ?enable_internet:bool ->
  t ->
  unit
```
Boots the container and returns at once, before it is ready to accept connections. `entrypoint` replaces the command of the image, `env` adds environment variables, and `enable_internet` allows outbound traffic. Raises [`Js_error`](./Workero.md#exception-Js_error) when the container already runs.

```ocaml
val monitor : t -> unit
```
Waits until the container exits. Raises [`Js_error`](./Workero.md#exception-Js_error) when it exits with an error, or when [`destroy`](./#val-destroy) gave a `message`. Suspends.

```ocaml
val destroy : ?message:string -> t -> unit
```
Stops the container, and fails [`monitor`](./#val-monitor) with `message` when given. Suspends.

```ocaml
val signal : t -> int -> unit
```
`signal container signo` sends the Unix signal number `signo`, for example `15` for `SIGTERM`, to the main process.

```ocaml
val get_tcp_port : t -> int -> Fetcher.t
```
A [`Fetcher.t`](./Workero-Fetcher.md#type-t) for a TCP port of the container: [`Fetcher.fetch`](./Workero-Fetcher.md#val-fetch) sends an HTTP request to the program that listens on that port. The host of the URL is ignored, so any host works, such as `"http://container/path"`. The program may need time to start: retry on [`Js_error`](./Workero.md#exception-Js_error). Raw TCP connections are not supported.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```