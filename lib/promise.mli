(** A JavaScript [Promise] of an OCaml value.

    The type is backed by [Js_of_ocaml.Promise]: a promise resolved with another
    promise is boxed, so ['a t t] holds a promise of a promise, where a raw
    JavaScript [Promise] would flatten it. *)

type +'a t

type error
(** A rejection reason. JavaScript allows any value, so the type is opaque. *)

exception Js_error of error
(** Raised by {!await} when the awaited promise rejects, and by the bindings
    when the runtime throws. It carries the original reason, so a handler can
    re-raise or inspect it with {!error_to_js}. {!Workero.Js_error} is this
    exception. *)

val error_of_exn : exn -> error
(** A rejection that carries an OCaml exception. {!await} re-raises that
    exception. When it reaches the runtime, it is a JavaScript [Error] whose
    message is [Printexc.to_string]. *)

val error_of_string : string -> error
(** [error_of_string msg] is a JavaScript [Error] with message [msg]. *)

val error_to_string : error -> string
(** The reason converted with JavaScript [String], for example ["Error: nope"].
*)

val error_of_js : Js_of_ocaml.Js.Unsafe.any -> error
val error_to_js : error -> Js_of_ocaml.Js.Unsafe.any

val make : (resolve:('a -> unit) -> reject:(error -> unit) -> unit) -> 'a t
(** [make executor] is [new Promise(executor)]. An exception raised by
    [executor] rejects the promise, like a throw in JavaScript. *)

val resolve : 'a -> 'a t
(** [Promise.resolve]. *)

val reject : error -> 'a t
(** [Promise.reject]. *)

val await : 'a t -> 'a
(** [await p] suspends the current request until [p] settles. It returns the
    resolved value. For a rejection made by {!error_of_exn}, [map], [bind],
    [make] or [of_js], it re-raises the original OCaml exception. For any other
    rejection it raises {!Js_error}. It works inside the handlers given to
    {!Workero.serve} and {!Workero.scheduled}, and inside the function given to
    {!Context.wait_until}. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** An exception raised by the function rejects the result, see {!await}. *)

val bind : ('a -> 'b t) -> 'a t -> 'b t
(** Like {!map}, for a function that returns a promise. *)

val all : 'a t list -> 'a list t
(** Resolves with every value, in order, or rejects with the first rejection. *)

val race : 'a t list -> 'a t
(** Settles like the first promise to settle. *)

val any : 'a t list -> 'a t
(** Resolves with the first value. When all reject, rejects with an
    [AggregateError]. *)

val all_settled : 'a t list -> ('a, error) result list t
(** Resolves when every promise has settled. It never rejects. *)

val of_js :
  decode:(Js_of_ocaml.Js.Unsafe.any -> 'a) -> Js_of_ocaml.Js.Unsafe.any -> 'a t
(** [of_js ~decode p] reads a raw JavaScript Promise and applies [decode] to its
    resolved value. If [decode] raises, the promise rejects with an [Error] that
    names the exception, so {!await} raises {!Js_error}. See {!Decode}. *)

val to_js : 'a t -> Js_of_ocaml.Js.Unsafe.any
(** The underlying JavaScript Promise. A thenable it resolves with is boxed, so
    raw JavaScript code sees a box and not the thenable. *)
