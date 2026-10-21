(** A JavaScript [Promise], bound directly. *)

type 'a t

val make : (resolve:('a -> unit) -> reject:(string -> unit) -> unit) -> 'a t
(** [make executor] is [new Promise(executor)]. [reject msg] rejects with a
    JavaScript [Error] whose message is [msg]. *)

val resolve : 'a -> 'a t
(** [Promise.resolve]. *)

val reject : string -> 'a t
(** [Promise.reject (new Error msg)]. *)

val await : 'a t -> 'a
(** [await p] suspends the current request until [p] settles. It returns the
    resolved value or raises {!Workero.Js_error}. It works inside the handlers
    given to {!Workero.serve} and {!Workero.scheduled}, and inside the function
    given to {!Context.wait_until}. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> 'a t
(** Views a raw JavaScript Promise. The caller states the type of the resolved
    value: a JavaScript string must be typed
    [Js_of_ocaml.Js.js_string Js_of_ocaml.Js.t], not [string]. *)

val to_js : 'a t -> Js_of_ocaml.Js.Unsafe.any
