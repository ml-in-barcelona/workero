(** Durable Objects with SQLite storage.

    A Durable Object class is a function from its {!State} and the {!Env} to the
    handlers of one object, built with {!make} and bound to a name with
    {!register}. Declare the class in [wrangler.toml] with [[durable_objects]]
    and a migration with [new_sqlite_classes], or with the [exports] map and
    [storage = "sqlite"]. [workero build] exports every registered class. Only
    SQLite-backed classes are supported: {!Storage} fails on a class backed by
    the legacy key-value storage.

    Handlers on one object interleave only where they suspend, so a handler that
    uses {!Storage} and never calls {!Promise.await} runs without interruption.
    Keep the state of an object in values created inside the function given to
    {!register}, never in module-level values: one isolate may host many
    objects, and the runtime may evict an object from memory and create it again
    later. *)

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
      so an [Int] is exact only within ±2{^ 53}; see {!Sql_value}. *)

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
  (** The storage of one object. The key-value functions are synchronous: they
      never suspend. Values are JSON, converted with [JSON.stringify] and
      [JSON.parse]. A [Date] stored by JavaScript code reads as its ISO string
      and a [Map] as [{}]. [get] and [list] raise [Invalid_argument] for a
      stored value that [JSON.stringify] rejects, such as a [BigInt] or a cyclic
      object. The functions raise {!Js_error} when the runtime throws, for
      example on a class that is not backed by SQLite. *)

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

module State : sig
  type t
  (** The [ctx] of an object. *)

  val id : t -> Id.t
  val storage : t -> Storage.t

  val wait_until : t -> (unit -> unit) -> unit
  (** Like {!Context.wait_until}. *)

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
  (** Accepts the server end of a {!Websocket.pair}. [tags] are at most 10
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
  unit ->
  t
(** [make ()] gives an object that handles no event. [init] runs under
    [blockConcurrencyWhile] before the first event, each time the object is
    created, and may call {!Promise.await}; if it raises, the runtime resets the
    object. [fetch] answers the requests that a stub sends. [alarm] runs when
    the alarm is due; an exception makes the runtime retry it. The [websocket_*]
    handlers get the events of sockets accepted with {!State.accept_websocket};
    [websocket_error] gets the error message. Every handler runs in its own
    fiber and may call {!Promise.await}. A stub fetch on an object without a
    [fetch] handler fails. *)

val register : string -> (State.t -> Env.t -> t) -> unit
(** [register class_name create] binds [create] to the class that
    [workero build] exports under [class_name]. Call it at module
    initialisation, once per class. The build reads the names by running the
    program in [workerd]; a [register] call that a condition skips at
    initialisation is not exported.

    [create] runs each time the runtime creates the object, before the first
    event. It must not call {!Promise.await}: that raises [Invalid_argument].
    Load stored values in [~init] of {!make}. If [create] raises, the object
    fails to start and the request that needed it fails.

    Raises [Invalid_argument] when [class_name] is empty, starts with a digit,
    has a character other than an ASCII letter, a digit, ["_"] or ["$"], is
    ["default"], ["then"] or ["__proto__"], or is already registered. Reserved
    words such as ["class"] are accepted: the generated module exports the class
    under that name without declaring a variable of it. *)

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
