
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
A [`Fetcher.t`](./Workero-Fetcher.md#type-t) for a TCP port of the container: [`Fetcher.fetch`](./Workero-Fetcher.md#val-fetch) sends an HTTP request to the program that listens on that port. The host of the URL is ignored, so any host works, such as `"http://container/path"`. The program may need time to start: retry on [`Js_error`](./Workero.md#exception-Js_error). For raw TCP, see [`connect`](./#val-connect).

```ocaml
val connect : t -> port:int -> Socket.t
```
`connect container ~port` opens a raw TCP connection to `port` of the container and returns at once. Call [`Socket.opened`](./Workero-Socket.md#val-opened) to wait for it; it raises [`Js_error`](./Workero.md#exception-Js_error) while the program does not listen yet. The runtime takes the address `"10.0.0.1:<port>"`; the container ignores the host. Raises `Invalid_argument` when `port` is outside 1 to 65535\.

```ocaml
val set_inactivity_timeout : t -> ms:int -> unit
```
Sets how long the container may run without a request before the runtime stops it. `ms` is 1 to 21600000 (6 hours). Suspends. Raises `Invalid_argument` when `ms` is outside that range.

```ocaml
val intercept_outbound_http : t -> string -> Fetcher.t -> unit
```
`intercept_outbound_http container address fetcher` sends the outbound HTTP requests (port 80\) of the container to `fetcher`, for example a service binding to the Worker, instead of the network. `address` is a host name, a host name pattern such as `"*.example.com"`, an IP address, `"ip:port"` or an IPv4 CIDR range. The target sees the original URL. Suspends. A container has 128 interceptors in all; more raise [`Js_error`](./Workero.md#exception-Js_error).

```ocaml
val intercept_all_outbound_http : t -> Fetcher.t -> unit
```
Like [`intercept_outbound_http`](./#val-intercept_outbound_http) for every outbound HTTP request on port 80\. HTTPS is not covered. Suspends.

```ocaml
val intercept_outbound_https : t -> string -> Fetcher.t -> unit
```
Like [`intercept_outbound_http`](./#val-intercept_outbound_http) for HTTPS. `address` is a host name or a pattern with an optional port; `"*"` means every host on port 443\. The container must trust `/etc/cloudflare/certs/cloudflare-containers-ca.crt`. Suspends.

```ocaml
val of_js : Js_of_ocaml.Js.Unsafe.any -> t
```
```ocaml
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
```