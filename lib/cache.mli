(** The global [caches.default] runtime API, not an [env] binding. Entries are
    keyed by URL string in the data center that runs the Worker. Operations
    suspend like {!Promise.await} and raise {!Js_error} when the runtime
    rejects. *)

val match_ : string -> Response.t option
(** [match_ url] is the cached response for [url], or [None]. *)

val put : string -> Response.t -> unit
(** [put url response] attempts to cache [response] under [url]. The runtime
    consumes its body; pass {!Response.clone} if you also send the response to
    the client. A resolved call does not guarantee that the response was stored.
    The Cache API respects [Cache-Control], does not cache [Set-Cookie]
    responses, and rejects status 206 or [Vary: *]. *)

val delete : string -> bool
(** [delete url] removes the entry. It is [false] when there was none. *)
