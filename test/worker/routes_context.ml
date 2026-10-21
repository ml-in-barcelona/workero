open Workero

let handle req _env ctx =
  match URL.path (Request.url req) with
  | "/context/pass-through" ->
      Context.pass_through_on_exception ctx;
      Some (Response.text "passed")
  | "/context/pass-through-raise" ->
      Context.pass_through_on_exception ctx;
      failwith "after pass-through"
  | _ -> None
