(** Decoders for raw JavaScript values, for {!Promise.of_js}. A decoder raises
    [Invalid_argument] naming the expected and the actual JavaScript type. *)

type 'a t = Js_of_ocaml.Js.Unsafe.any -> 'a

val js : Js_of_ocaml.Js.Unsafe.any t
(** The value, undecoded. *)

val unit : unit t
(** Accepts any value and drops it. *)

val string : string t

val int : int t
(** Raises [Invalid_argument] for a number with a fraction or outside the range
    of the OCaml [int]. *)

val float : float t
val bool : bool t

val bytes : string t
(** An [ArrayBuffer], a typed array or an array of byte numbers, as raw bytes.
*)

val option : 'a t -> 'a option t
(** [None] for [null] and [undefined]. *)

val list : 'a t -> 'a list t
(** A JavaScript array. *)

val field : string -> 'a t -> 'a t
(** [field name d] decodes the property [name] of an object or function. *)
