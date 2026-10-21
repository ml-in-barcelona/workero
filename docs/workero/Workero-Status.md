
# Module `Workero.Status`

HTTP status codes as polymorphic variants, with the names and groups of Dream. ``Status n` stands for any other code.

```ocaml
type informational = [ 
  | `Continue
  | `Switching_Protocols
 ]
```
```ocaml
type successful = [ 
  | `OK
  | `Created
  | `Accepted
  | `Non_Authoritative_Information
  | `No_Content
  | `Reset_Content
  | `Partial_Content
 ]
```
```ocaml
type redirection = [ 
  | `Multiple_Choices
  | `Moved_Permanently
  | `Found
  | `See_Other
  | `Not_Modified
  | `Temporary_Redirect
  | `Permanent_Redirect
 ]
```
```ocaml
type client_error = [ 
  | `Bad_Request
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
  | `Unavailable_For_Legal_Reasons
 ]
```
```ocaml
type server_error = [ 
  | `Internal_Server_Error
  | `Not_Implemented
  | `Bad_Gateway
  | `Service_Unavailable
  | `Gateway_Timeout
  | `HTTP_Version_Not_Supported
 ]
```
```ocaml
type no_body = [ 
  | `No_Content
  | `Reset_Content
  | `Not_Modified
 ]
```
Statuses whose responses carry no body.

```ocaml
type redirect = [ 
  | `Moved_Permanently
  | `Found
  | `See_Other
  | `Temporary_Redirect
  | `Permanent_Redirect
 ]
```
Statuses that [`Response.redirect`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-redirect) accepts.

```ocaml
type with_body = [ 
  | `OK
  | `Created
  | `Accepted
  | `Non_Authoritative_Information
  | `Partial_Content
  | `Multiple_Choices
  | redirect
  | client_error
  | server_error
  | `Status of int
 ]
```
Statuses [`Response.text`](https://ml-in-barcelona.github.io/workero/workero/Workero/Response/index.html#val-text) and the other body constructors accept. `Continue` and `Switching_Protocols` are left out: the runtime rejects them in a response built without a WebSocket.

```ocaml
type t = [ 
  | informational
  | no_body
  | with_body
 ]
```
Any status.

```ocaml
val to_int : [< t ] -> int
```
The numeric code, such as `404` for ``Not_Found`.

```ocaml
val of_int : int -> t
```
`of_int n` is the standard tag for `n`, or ``Status n` when `n` has none.

```ocaml
val to_string : [< t ] -> string
```
The reason phrase, such as `"Not Found"`. ``Status n` with no standard tag gives `string_of_int n`.
