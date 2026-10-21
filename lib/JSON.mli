(** JSON requests and responses for workero ([Workero.JSON]), built on
    {{:https://github.com/melange-community/jsonkit} jsonkit}.

    A JSON value is a [Jsonkit.t], which is a [Yojson.Basic.t]. Decode it to
    your own types with the [Jsonkit.Of_json] combinators, or derive the
    functions with [jsonkit.ppx]. Add [(preprocess (pps jsonkit.ppx))] to your
    [dune] file and write:

    {[
    open Jsonkit.Primitives

    type user = { name : string; age : int } [@@deriving json]

    let handler req _env _ctx =
      match Workero.JSON.decode user_of_json req with
      | Ok user -> Workero.JSON.response (user_to_json user)
      | Error message -> Workero.JSON.bad_request message
    ]}

    Without the ppx, write the decoder by hand:

    {[
    let user_of_json json =
      Jsonkit.Of_json.
        { name = json |> field "name" string; age = json |> field "age" int }
    ]} *)

type t = Jsonkit.t
(** A JSON value. *)

val response : ?status:int -> ?headers:(string * string) list -> t -> Response.t
(** [response json] is a response with status 200 and the compact JSON text as
    body. It adds [content-type: application/json; charset=utf-8] unless
    [headers] already has a [content-type] (any letter case). Non-ASCII
    characters are sent as UTF-8. *)

val bad_request : ?status:int -> string -> Response.t
(** [bad_request message] is a response with status 400 and the body
    [{"error": message}]. *)

val of_request : Request.t -> t
(** Reads the whole body and parses it as JSON.

    Raises [Jsonkit.Of_string_error] when the body is not valid JSON. The
    payload describes the syntax error. A handler that lets it escape makes the
    runtime answer with status 500; use {!of_request_result} or {!decode} to
    answer with 400. *)

val of_request_result : Request.t -> (t, string) result
(** Like {!of_request}. [Error message] when the body is not valid JSON. *)

val decode : (t -> 'a) -> Request.t -> ('a, string) result
(** [decode of_json req] parses the body and applies [of_json]. [of_json] is a
    jsonkit decoder, for example [user_of_json] from [[@@deriving json]], or
    [Jsonkit.Of_json.(list int)]. [Error message] when the body is not valid
    JSON or when [of_json] raises [Jsonkit.Of_json_error]. *)
