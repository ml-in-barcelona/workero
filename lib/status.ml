(* Status names and groups follow Dream (https://github.com/aantron/dream),
   Copyright 2021 Anton Bachin, released under the MIT license. *)

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

type redirect =
  [ `Moved_Permanently
  | `Found
  | `See_Other
  | `Temporary_Redirect
  | `Permanent_Redirect ]

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

type t = [ informational | no_body | with_body ]

let table : (t * int * string) list =
  [
    (`Continue, 100, "Continue");
    (`Switching_Protocols, 101, "Switching Protocols");
    (`OK, 200, "OK");
    (`Created, 201, "Created");
    (`Accepted, 202, "Accepted");
    (`Non_Authoritative_Information, 203, "Non-Authoritative Information");
    (`No_Content, 204, "No Content");
    (`Reset_Content, 205, "Reset Content");
    (`Partial_Content, 206, "Partial Content");
    (`Multiple_Choices, 300, "Multiple Choices");
    (`Moved_Permanently, 301, "Moved Permanently");
    (`Found, 302, "Found");
    (`See_Other, 303, "See Other");
    (`Not_Modified, 304, "Not Modified");
    (`Temporary_Redirect, 307, "Temporary Redirect");
    (`Permanent_Redirect, 308, "Permanent Redirect");
    (`Bad_Request, 400, "Bad Request");
    (`Unauthorized, 401, "Unauthorized");
    (`Payment_Required, 402, "Payment Required");
    (`Forbidden, 403, "Forbidden");
    (`Not_Found, 404, "Not Found");
    (`Method_Not_Allowed, 405, "Method Not Allowed");
    (`Not_Acceptable, 406, "Not Acceptable");
    (`Proxy_Authentication_Required, 407, "Proxy Authentication Required");
    (`Request_Timeout, 408, "Request Timeout");
    (`Conflict, 409, "Conflict");
    (`Gone, 410, "Gone");
    (`Length_Required, 411, "Length Required");
    (`Precondition_Failed, 412, "Precondition Failed");
    (`Payload_Too_Large, 413, "Payload Too Large");
    (`URI_Too_Long, 414, "URI Too Long");
    (`Unsupported_Media_Type, 415, "Unsupported Media Type");
    (`Range_Not_Satisfiable, 416, "Range Not Satisfiable");
    (`Expectation_Failed, 417, "Expectation Failed");
    (`Misdirected_Request, 421, "Misdirected Request");
    (`Too_Early, 425, "Too Early");
    (`Upgrade_Required, 426, "Upgrade Required");
    (`Precondition_Required, 428, "Precondition Required");
    (`Too_Many_Requests, 429, "Too Many Requests");
    (`Request_Header_Fields_Too_Large, 431, "Request Header Fields Too Large");
    (`Unavailable_For_Legal_Reasons, 451, "Unavailable For Legal Reasons");
    (`Internal_Server_Error, 500, "Internal Server Error");
    (`Not_Implemented, 501, "Not Implemented");
    (`Bad_Gateway, 502, "Bad Gateway");
    (`Service_Unavailable, 503, "Service Unavailable");
    (`Gateway_Timeout, 504, "Gateway Timeout");
    (`HTTP_Version_Not_Supported, 505, "HTTP Version Not Supported");
  ]

let to_int (s : [< t ]) =
  match (s :> t) with
  | `Status n -> n
  | s ->
      let _, code, _ = List.find (fun (t, _, _) -> t = s) table in
      code

let of_int n : t =
  match List.find_opt (fun (_, code, _) -> code = n) table with
  | Some (t, _, _) -> t
  | None -> `Status n

let to_string (s : [< t ]) =
  match of_int (to_int s) with
  | `Status n -> string_of_int n
  | s ->
      let _, _, phrase = List.find (fun (t, _, _) -> t = s) table in
      phrase
