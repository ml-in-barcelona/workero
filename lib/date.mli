(** JavaScript [Date]. Times are milliseconds since the Unix epoch, as a
    [float]. In Workers, the clock advances only after I/O, so it does not
    measure CPU time. *)

val now : unit -> float
(** [Date.now()]. *)

val to_iso_string : float -> string
(** [to_iso_string t] is [new Date(t).toISOString()], for example
    ["1970-01-01T00:00:00.000Z"] for [0.].

    Raises [Invalid_argument] when [t] is not a valid time, for example [nan].
*)
