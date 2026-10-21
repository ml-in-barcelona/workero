type t

val text : ?status:int -> ?headers:(string * string) list -> string -> t
(** A UTF-8 text body. The runtime sets [content-type] to
    [text/plain;charset=UTF-8] unless [headers] has one. [status] is 200 by
    default. A status that allows no body (101, 204, 205, 304) works with the
    empty string, which is sent as no body. A non-empty body with such a status
    is rejected by the runtime when the response is built. *)

val html : ?status:int -> ?headers:(string * string) list -> string -> t
(** Like {!text}, with [content-type: text/html; charset=utf-8] unless [headers]
    has a [content-type]. *)

val bytes : ?status:int -> ?headers:(string * string) list -> string -> t
(** [bytes body] sends the bytes of [body] as they are, with no [content-type]
    unless [headers] has one. *)

val redirect : ?status:int -> string -> t
(** [redirect url] answers with a [location] header. [url] must be absolute,
    such as ["https://example.com/login"]; the runtime rejects a relative one
    like ["/login"]. [status] is 302 by default.

    Raises [Invalid_argument] when [status] is not one of 301, 302, 303, 307 and
    308. *)

val status : t -> int

val header : t -> string -> string option
(** See {!Request.header}. *)

val headers : t -> (string * string) list
(** See {!Request.headers}. *)

val body_text : t -> string
(** Reads the whole body as UTF-8 text. Suspends like {!Promise.await}. *)

val body_bytes : t -> string
(** Reads the whole body as raw bytes. Suspends like {!Promise.await}. *)

val of_js : Js_of_ocaml.Js.Unsafe.any -> t
val to_js : t -> Js_of_ocaml.Js.Unsafe.any
