(** Durable Objects with SQLite-backed key-value and SQL storage.

    A Durable Object class is a function from its {!State} and the {!Env} to the
    handlers of one object, built with {!make} and bound to a name with
    {!register}. Declare the class in [wrangler.toml] with [[durable_objects]]
    and a migration with [new_sqlite_classes], or with the [exports] map and
    [storage = "sqlite"]. [workero build] exports every registered class.
    {!Storage} requires a SQLite-backed class; its key-value and SQL methods
    fail on legacy storage. [fetch], [alarm], and hibernatable WebSocket event
    handlers are exported. Durable Object RPC methods are not exported.

    Handlers on one object interleave only where they suspend, so a handler that
    uses only the synchronous key-value methods and never calls {!Promise.await}
    runs without interruption. Keep the state of an object in values created
    inside the function given to {!register}, never in module-level values: one
    isolate may host many objects, and the runtime may evict an object from
    memory and create it again later. *)

module Id : sig
  type t
  (** The identity of one object. *)

  val to_string : t -> string
  (** 64 hexadecimal digits. {!Namespace.id_from_string} reads it back. *)

  val name : t -> string option
  (** The name given to {!Namespace.id_from_name}; [None] for
      {!Namespace.unique_id} and when the runtime does not report it. *)

  val equal : t -> t -> bool
  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end

module Sql : sig
  (** The SQLite database of an object. Calls are synchronous: they never
      suspend. An SQL error raises {!Js_error}. Numbers are JavaScript numbers,
      so an [Int] is exact only within ±[2^53]; see {!Sql_value}. *)

  type t

  val query : ?params:Sql_value.t list -> t -> string -> Sql_value.row list
  (** [query sql_db statement] runs [statement], with [params] bound to its [?]
      marks in order, and returns every row. *)

  val run : ?params:Sql_value.t list -> t -> string -> int
  (** Runs a statement and returns the number of rows it wrote. It reads the
      cursor to its end first, because the count is final only then. *)

  val database_size : t -> int
  (** The size of the database in bytes. *)

  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end

module Storage : sig
  (** The storage of one object. [get], [put], [delete], and [list] do not
      suspend; [delete_all], [sync], and the alarm methods do. Values are JSON,
      converted with [JSON.stringify] and [JSON.parse]. A [Date] stored by
      JavaScript code reads as its ISO string and a [Map] as [{}]. [get] and
      [list] raise [Invalid_argument] for a stored value that [JSON.stringify]
      rejects, such as a [BigInt] or a cyclic object. The functions raise
      {!Js_error} when the runtime throws, for example on a class that is not
      backed by SQLite. *)

  type t

  val get : t -> string -> Jsonkit.t option
  (** [None] when the key is absent. *)

  val put : t -> string -> Jsonkit.t -> unit

  val delete : t -> string -> bool
  (** [true] when the key existed. *)

  val list :
    ?prefix:string ->
    ?start:string ->
    ?end_:string ->
    ?reverse:bool ->
    ?limit:int ->
    t ->
    (string * Jsonkit.t) list
  (** Entries in key order ([reverse] flips it). [start] is inclusive and [end_]
      is exclusive. *)

  val sql : t -> Sql.t

  val transaction_sync : t -> (unit -> 'a) -> 'a
  (** [transaction_sync storage f] runs [f] in a transaction and returns its
      result. If [f] raises, every write of [f] to storage and to SQL is rolled
      back and the same exception reaches the caller. [f] cannot suspend: a call
      to {!Promise.await} in it raises [Invalid_argument]. *)

  type transaction
  (** The handle of a running {!transaction}. *)

  val transaction : t -> (transaction -> 'a) -> 'a
  (** [transaction storage f] runs [f] in a transaction and returns its result.
      Unlike {!transaction_sync}, [f] may call {!Promise.await}. Every write of
      [f] to storage and to SQL, made through [storage] or its {!sql}, commits
      when [f] returns. If [f] raises, those writes are rolled back and the same
      exception reaches the caller. Calls to [transaction] in [f] nest: a nested
      transaction that raises rolls back alone. Suspends. *)

  val rollback : transaction -> unit
  (** Rolls back the writes of the transaction so far and lets [f] go on
      running: writes after [rollback] are not part of the transaction, so raise
      to stop instead when they must not happen. Raises {!Js_error} when the
      transaction has ended. *)

  val delete_all : t -> unit
  (** Deletes every key-value pair. It does not delete an alarm. Suspends. *)

  val sync : t -> unit
  (** Waits until earlier writes are durable. Suspends. *)

  (** {2 Alarms}

      An object has at most one alarm. When it is due, the runtime calls the
      [alarm] handler of the object, wakes the object up if it was evicted, and
      retries a failing handler. A class that gives no [alarm] to {!make} still
      accepts {!set_alarm}; its alarm fails and is retried until the runtime
      gives up. These functions suspend. *)

  val get_alarm : t -> float option
  (** The scheduled time, in milliseconds since the Unix epoch, or [None] when
      there is no alarm. *)

  val set_alarm :
    ?allow_concurrency:bool -> ?allow_unconfirmed:bool -> t -> at:float -> unit
  (** [set_alarm storage ~at] schedules the alarm at [at], in milliseconds since
      the Unix epoch, and replaces an earlier alarm. A time in the past runs the
      handler at once. *)

  val set_alarm_after :
    ?allow_concurrency:bool -> ?allow_unconfirmed:bool -> t -> ms:float -> unit
  (** [set_alarm_after storage ~ms] is {!set_alarm} with [at] set to {!Date.now}
      plus [ms]. *)

  val delete_alarm : t -> unit
  (** Cancels the alarm. It does nothing when there is none. *)

  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end

module Container : sig
  (** The container attached to an object, on Cloudflare Containers. Declare it
      in [wrangler.toml] with [[[containers]]] and the class name of the object.
      The container starts only when {!start} runs. The functions raise
      {!Js_error} when the runtime throws or rejects, for example when no image
      is configured or the container is not running.

      [workerd] runs a container only with Docker: see
      {{!page-durable_objects}Durable Objects}. *)

  type t

  val running : t -> bool
  (** [true] once {!start} ran and until the container exits or is destroyed. It
      does not mean that the program in the container accepts connections. *)

  val start :
    ?entrypoint:string list ->
    ?env:(string * string) list ->
    ?enable_internet:bool ->
    t ->
    unit
  (** Boots the container and returns at once, before it is ready to accept
      connections. [entrypoint] replaces the command of the image, [env] adds
      environment variables, and [enable_internet] allows outbound traffic.
      Raises {!Js_error} when the container already runs. *)

  val monitor : t -> unit
  (** Waits until the container exits. Raises {!Js_error} when it exits with an
      error, or when {!destroy} gave a [message]. Suspends. *)

  val destroy : ?message:string -> t -> unit
  (** Stops the container, and fails {!monitor} with [message] when given.
      Suspends. *)

  val signal : t -> int -> unit
  (** [signal container signo] sends the Unix signal number [signo], for example
      [15] for [SIGTERM], to the main process. *)

  val get_tcp_port : t -> int -> Fetcher.t
  (** A {!Fetcher.t} for a TCP port of the container: {!Fetcher.fetch} sends an
      HTTP request to the program that listens on that port. The host of the URL
      is ignored, so any host works, such as ["http://container/path"]. The
      program may need time to start: retry on {!Js_error}. For raw TCP, see
      {!connect}. *)

  val connect : t -> port:int -> Socket.t
  (** [connect container ~port] opens a raw TCP connection to [port] of the
      container and returns at once. Call {!Socket.opened} to wait for it; it
      raises {!Js_error} while the program does not listen yet. The runtime
      takes the address ["10.0.0.1:<port>"]; the container ignores the host.
      Raises [Invalid_argument] when [port] is outside 1 to 65535. *)

  val set_inactivity_timeout : t -> ms:int -> unit
  (** Sets how long the container may run without a request before the runtime
      stops it. [ms] is 1 to 21600000 (6 hours). Suspends. Raises
      [Invalid_argument] when [ms] is outside that range. *)

  val intercept_outbound_http : t -> string -> Fetcher.t -> unit
  (** [intercept_outbound_http container address fetcher] sends the outbound
      HTTP requests (port 80) of the container to [fetcher], for example a
      service binding to the Worker, instead of the network. [address] is a host
      name, a host name pattern such as ["*.example.com"], an IP address,
      ["ip:port"] or an IPv4 CIDR range. The target sees the original URL.
      Suspends. A container has 128 interceptors in all; more raise {!Js_error}.
  *)

  val intercept_all_outbound_http : t -> Fetcher.t -> unit
  (** Like {!intercept_outbound_http} for every outbound HTTP request on port
      80. HTTPS is not covered. Suspends. *)

  val intercept_outbound_https : t -> string -> Fetcher.t -> unit
  (** Like {!intercept_outbound_http} for HTTPS. [address] is a host name or a
      pattern with an optional port; ["*"] means every host on port 443. The
      container must trust [/etc/cloudflare/certs/cloudflare-containers-ca.crt].
      Suspends. *)

  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end

module State : sig
  type t
  (** The [ctx] of an object. *)

  val id : t -> Id.t
  val storage : t -> Storage.t

  val wait_until : t -> (unit -> unit) -> unit
  (** Like {!Context.wait_until}. *)

  val container : t -> Container.t option
  (** The container of the object, or [None] when the class has none. *)

  val block_concurrency_while : t -> (unit -> 'a) -> 'a
  (** [block_concurrency_while state f] runs [f] in its own fiber and lets no
      other event reach the object until [f] returns. [f] may call
      {!Promise.await}. If [f] raises, the runtime resets the object and fails
      the running requests, including the one that called this function; the
      next request creates the object again. Suspends. Raises [Invalid_argument]
      when called from the function given to {!register}; use [~init] there. *)

  (** {2 Hibernatable WebSockets}

      Sockets accepted with {!accept_websocket} stay connected while the object
      is evicted from memory. The runtime creates the object again when a
      message arrives and calls the [websocket_*] handlers of {!make}. Keep
      per-socket state in {!Websocket.serialize_attachment}, not in memory. A
      socket accepted with {!Websocket.accept} does not hibernate; do not mix
      the two on one socket. *)

  val accept_websocket : ?tags:string list -> t -> Websocket.t -> unit
  (** Accepts the server end of a {!Websocket.val-pair}. [tags] are at most 10
      strings of at most 256 characters; a violation raises {!Js_error}. *)

  val websockets : ?tag:string -> t -> Websocket.t list
  (** The accepted sockets, or those with [tag]. *)

  val tags : t -> Websocket.t -> string list

  val set_websocket_auto_response :
    t -> request:string -> response:string -> unit
  (** Answers a text message equal to [request] with [response], without waking
      the object. *)

  val of_js : Js_of_ocaml.Js.Unsafe.any -> t
  val to_js : t -> Js_of_ocaml.Js.Unsafe.any
end

type alarm_info = { retry_count : int; is_retry : bool }
(** [retry_count] is 0 on the first attempt. *)

type t
(** The handlers of one object. *)

val make :
  ?init:(unit -> unit) ->
  ?fetch:(Request.t -> Response.t) ->
  ?alarm:(alarm_info -> unit) ->
  ?websocket_message:(Websocket.t -> Websocket.message -> unit) ->
  ?websocket_close:
    (Websocket.t -> code:int -> reason:string -> was_clean:bool -> unit) ->
  ?websocket_error:(Websocket.t -> string -> unit) ->
  ?rpc:(string -> Jsonkit.t list -> Jsonkit.t) ->
  unit ->
  t
(** [make ()] gives an object that handles no event. [init] runs under
    [blockConcurrencyWhile] before the first event, each time the object is
    created, and may call {!Promise.await}; if it raises, the runtime resets the
    object. [fetch] answers the requests that a stub sends. [alarm] runs when
    the alarm is due; an exception makes the runtime retry it. The [websocket_*]
    handlers get the events of sockets accepted with {!State.accept_websocket};
    [websocket_error] gets the error message. [rpc] answers the calls of the
    methods that {!register} declared: [rpc name args] gets the method name and
    the arguments as JSON, and returns the result as JSON. See {!register}.
    Every handler runs in its own fiber and may call {!Promise.await}. A stub
    fetch on an object without a [fetch] handler fails. *)

val register : ?rpc:string list -> string -> (State.t -> Env.t -> t) -> unit
(** [register class_name create] binds [create] to the class that
    [workero build] exports under [class_name]. Call it at module
    initialisation, once per class. The build reads the names by running the
    program in [workerd]; a [register] call that a condition skips at
    initialisation is not exported.

    [create] runs each time the runtime creates the object, before the first
    event. It must not call {!Promise.await}: that raises [Invalid_argument].
    Load stored values in [~init] of {!make}. If [create] raises, the object
    fails to start and the request that needed it fails.

    [rpc] names the RPC methods of the class, for example [["increment"]]. The
    build adds each name as a method of the exported class, so JavaScript code
    calls [stub.increment(...)] and OCaml code calls {!call}. The [rpc] handler
    of {!make} runs each call. A name must follow the rules of [class_name],
    must be unique in the class, and must not be [fetch], [alarm], [connect],
    [constructor], [prototype], [webSocketMessage], [webSocketClose] or
    [webSocketError]. Declare the names here, not in [create]: the build reads
    them before any object exists. A call to a declared name on a class whose
    handlers have no [rpc] fails.

    Raises [Invalid_argument] when [class_name] is empty, starts with a digit,
    has a character other than an ASCII letter, a digit, ["_"] or ["$"], is
    ["default"], ["then"] or ["__proto__"], or is already registered. Reserved
    words such as ["class"] are accepted: the generated module exports the class
    under that name without declaring a variable of it. It also raises
    [Invalid_argument] for an invalid or repeated name in [rpc]. *)

val call : Fetcher.t -> string -> Jsonkit.t list -> Jsonkit.t
(** [call stub name args] calls the RPC method [name] of the object that [stub]
    reaches, with [args], and waits for the result. Arguments and result are
    JSON, converted like {!Storage} values: a JavaScript [undefined] result
    reads as [`Null], and a value that [JSON.stringify] rejects raises
    [Invalid_argument]. The runtime creates the object on the first call.
    Suspends. Raises {!Js_error} when the method is missing or when it raises or
    rejects; the error message is that of the remote exception. *)

module Namespace : sig
  type t
  (** A [[durable_objects]] binding. *)

  type location_hint = Wnam | Enam | Sam | Weur | Eeur | Apac | Oc | Afr | Me
  type jurisdiction = Eu | Fedramp

  val of_env : Env.t -> string -> t
  (** Raises [Invalid_argument] when [env] has no binding [name], or when the
      binding is not a Durable Object namespace. *)

  val id_from_name : t -> string -> Id.t
  (** The same name always gives the same id. *)

  val id_from_string : t -> string -> Id.t
  (** Reads an id written by {!Id.to_string}. Raises {!Js_error} when the string
      is not an id of this namespace. *)

  val unique_id : ?jurisdiction:jurisdiction -> t -> Id.t
  (** A new random id. *)

  val get : ?location_hint:location_hint -> t -> Id.t -> Fetcher.t
  (** The stub of an object: a {!Fetcher.t} whose [fetch] reaches the [fetch]
      handler of the object. The runtime creates the object on its first
      request. [location_hint] matters only when the object is created. *)

  val get_by_name : ?location_hint:location_hint -> t -> string -> Fetcher.t
  (** [get_by_name ns name] is [get ns (id_from_name ns name)]. *)
end
