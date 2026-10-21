(** A value of an SQL column, as sent to and received from a JavaScript SQL API
    such as D1. *)

type t =
  | Null
  | Int of int64
  | Float of float
  | Text of string
  | Blob of string
      (** [Blob] holds raw bytes.

          SQL APIs on the Workers runtime carry numbers as JavaScript numbers,
          which are 64-bit floats. An [Int] is exact only within ±2{^ 53}, and a
          column holding [1.0] cannot be told apart from [1]: both are read as
          [Int 1L]. [Float] is read only for numbers with a fractional part or
          beyond 2{^ 53}. *)

type row = (string * t) list
(** The columns of a row in result order, with their names. *)

val to_js : t -> Js_of_ocaml.Js.Unsafe.any
(** The JavaScript value to bind: [null], a number, a string or a [Uint8Array].

    Raises [Invalid_argument] for an [Int] beyond ±2{^ 53}, which a JavaScript
    number cannot hold exactly. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
(** Reads a JavaScript value: [null] or [undefined] is [Null]; a number with no
    fractional part within ±2{^ 53} is [Int]; any other number is [Float]; a
    [bigint] is [Int], exact in 64 bits; a string is [Text]; an [ArrayBuffer], a
    typed array or an array of byte numbers is [Blob].

    Raises [Invalid_argument] for any other JavaScript value, and for a [bigint]
    outside the int64 range. *)
