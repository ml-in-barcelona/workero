(* Status names and groups follow Dream (https://github.com/aantron/dream),
   Copyright 2021 Anton Bachin, released under the MIT license. *)

(** HTTP status codes as polymorphic variants, with the names and groups of
    Dream. [`Status n] stands for any other code. *)

type informational = [ `Continue | `Switching_Protocols ]

type successful =
  [ `OK
  | `Created
  | `Accepted
  | `Non_Authoritative_Information
  | `No_Content
  | `Reset_Content
  | `Partial_Content ]

type redirection =
  [ `Multiple_Choices
  | `Moved_Permanently
  | `Found
  | `See_Other
  | `Not_Modified
  | `Temporary_Redirect
  | `Permanent_Redirect ]

type client_error =
  [ `Bad_Request
  | `Unauthorized
  | `Payment_Required
  | `Forbidden
  | `Not_Found
  | `Method_Not_Allowed
  | `Not_Acceptable
  | `Proxy_Authentication_Required
  | `Request_Timeout
  | `Conflict
  | `Gone
  | `Length_Required
  | `Precondition_Failed
  | `Payload_Too_Large
  | `URI_Too_Long
  | `Unsupported_Media_Type
  | `Range_Not_Satisfiable
  | `Expectation_Failed
  | `Misdirected_Request
  | `Too_Early
  | `Upgrade_Required
  | `Precondition_Required
  | `Too_Many_Requests
  | `Request_Header_Fields_Too_Large
  | `Unavailable_For_Legal_Reasons ]

type server_error =
  [ `Internal_Server_Error
  | `Not_Implemented
  | `Bad_Gateway
  | `Service_Unavailable
  | `Gateway_Timeout
  | `HTTP_Version_Not_Supported ]

type no_body = [ `No_Content | `Reset_Content | `Not_Modified ]
(** Statuses whose responses carry no body. *)

type redirect =
  [ `Moved_Permanently
  | `Found
  | `See_Other
  | `Temporary_Redirect
  | `Permanent_Redirect ]
(** Statuses that {!Response.redirect} accepts. *)

type with_body =
  [ `OK
  | `Created
  | `Accepted
  | `Non_Authoritative_Information
  | `Partial_Content
  | `Multiple_Choices
  | redirect
  | client_error
  | server_error
  | `Status of int ]
(** Statuses {!Response.text} and the other body constructors accept. [Continue]
    and [Switching_Protocols] are left out: the runtime rejects them in a
    response built without a WebSocket. *)

type t = [ informational | no_body | with_body ]
(** Any status. *)

val to_int : [< t ] -> int
(** The numeric code, such as [404] for [`Not_Found]. *)

val of_int : int -> t
(** [of_int n] is the standard tag for [n], or [`Status n] when [n] has none. *)

val to_string : [< t ] -> string
(** The reason phrase, such as ["Not Found"]. [`Status n] with no standard tag
    gives [string_of_int n]. *)
