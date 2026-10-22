(** [WorkerEntrypoint] classes with RPC methods.

    An entrypoint class is a set of named methods that other Workers call
    through a service binding, like [env.MATH.add(1, 2)] in JavaScript. Declare
    one with {!register}. [workero build] exports every registered class, so a
    binding can name it with [entrypoint = "Math"] in [wrangler.toml]:
    {v
      [[services]]
      binding = "MATH"
      service = "my-worker"
      entrypoint = "Math"
    v}
    Another Worker, in JavaScript or OCaml, calls the methods of that binding.
    Use {!call} from OCaml.

    Arguments and results are JSON values. Other types that RPC supports, such
    as [Uint8Array], [Date] or stubs, are not supported. A method that returns
    nothing in JavaScript gives [`Null] to {!call}. *)

type t
(** The handlers of one entrypoint instance. *)

val make :
  ?fetch:(Request.t -> Response.t) ->
  ?rpc:(string -> Jsonkit.t list -> Jsonkit.t) ->
  unit ->
  t
(** [make ()] gives an entrypoint that answers no call. [fetch] answers requests
    sent to the binding with {!Fetcher.fetch}. [rpc] answers the calls of the
    methods that {!register} declared: [rpc name args] gets the method name and
    the arguments, and returns the result. It decides what an unknown name does;
    raise an exception to reject the call. Every handler runs in its own fiber
    and may call {!Promise.await}. An exception raised by a handler rejects the
    call, so the caller gets an error. *)

val register : ?rpc:string list -> string -> (Env.t -> Context.t -> t) -> unit
(** [register ~rpc class_name create] binds [create] to the class that
    [workero build] exports under [class_name]. Call it at module
    initialisation, once per class. [rpc] lists the method names, for example
    [["add"]]. The build reads them by running the program in [workerd], before
    it has an {!Env.t}, so they are given here and answered by the [rpc] handler
    of {!make}. A call to a declared name on a class whose handlers have no
    [rpc] fails.

    [create] gets the [env] and the [ctx] of the instance, so a method can call
    {!Context.wait_until}. It runs for each call, as the runtime creates a new
    instance of the class for each call. It must not call {!Promise.await}: that
    raises [Invalid_argument]. Keep no state in the instance; two calls can run
    in different instances. If [create] raises, the call fails.

    Raises [Invalid_argument] when [class_name] is not a valid class name (see
    {!Durable_object.register}), when it is also the name of a Durable Object
    class or of a Workflow or another entrypoint, or when [rpc] has a duplicate
    or a name that is not a JavaScript identifier. The names [constructor],
    [prototype], [__proto__], [then], [env], [ctx], [fetch], [scheduled],
    [queue], [email], [tail], [trace], [tailStream], [test], [connect] and [dup]
    are reserved. *)

val call : Fetcher.t -> string -> Jsonkit.t list -> Jsonkit.t
(** [call binding name args] calls the RPC method [name] of the entrypoint
    behind [binding], a service binding read with {!Fetcher.of_env}, and waits
    for the result. A result that is [undefined] in JavaScript gives [`Null].
    Suspends like {!Promise.await}.

    Raises {!Js_error} when the method does not exist, when it raises, or when
    the runtime rejects the call. Raises [Invalid_argument] when the result has
    no JSON form, or when an argument has none. *)
