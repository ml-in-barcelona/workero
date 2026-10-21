(** The Cache API of the data center that runs the Worker ([caches.default]).
    Entries are keyed by URL, and each data center has its own cache. Each
    function suspends like {!Promise.await} and raises {!Js_error} when the
    runtime rejects. *)

val match_ : string -> Response.t option
(** [match_ url] is the cached response for [url], or [None]. *)

val put : string -> Response.t -> unit
(** [put url response] caches [response] under [url]. The runtime consumes the
    body of [response], so send a copy to the client. It rejects a response with
    status 206 or a [Vary: *] header, and caches it only as long as its
    [Cache-Control] header allows. *)

val delete : string -> bool
(** [delete url] removes the entry. It is [false] when there was none. *)
