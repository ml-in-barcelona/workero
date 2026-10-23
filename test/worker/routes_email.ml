open Workero

let hex s =
  String.concat ""
    (List.init (String.length s) (fun i ->
         Printf.sprintf "%02x" (Char.code s.[i])))

let opt = Option.value ~default:"none"
let destination = "dest@example.com"

let receive message _env ctx =
  let report text = Email.set_reject message text in
  match Email.to_ message with
  | "accessors@example.com" ->
      report
        (Printf.sprintf
           "from=%s;to=%s;size=%d;subject=%s;tag=%s;tags=%s;missing=%s;count=%d"
           (Email.from message) (Email.to_ message) (Email.raw_size message)
           (opt (Email.header message "SUBJECT"))
           (opt (Email.header message "x-tag"))
           (String.concat "|" (Email.header_all message "X-Tag"))
           (opt (Email.header message "x-missing"))
           (List.length (Email.headers message)))
  | "headers@example.com" ->
      report
        (String.concat ";"
           (List.map (fun (k, v) -> k ^ "=" ^ v) (Email.headers message)))
  | "raw-text@example.com" -> report ("text=" ^ Email.raw_text message)
  | "raw-bytes@example.com" -> report ("bytes=" ^ hex (Email.raw_bytes message))
  | "raw-stream@example.com" ->
      let chunks = ref 0 and total = ref 0 in
      Stream.iter
        (fun chunk ->
          incr chunks;
          total := !total + String.length chunk)
        (Email.raw message);
      report (Printf.sprintf "chunks=%d;total=%d" !chunks !total)
  | "raw-twice@example.com" ->
      let first = Email.raw_text message in
      let second =
        match Email.raw_text message with
        | _ -> "no error"
        | exception Js_error _ -> "error"
      in
      report (Printf.sprintf "first=%d;second=%s" (String.length first) second)
  | "forward@example.com" -> Email.forward message destination
  | "forward-headers@example.com" ->
      Email.forward
        ~headers:[ ("X-Seen", "yes"); ("X-Via", "workero") ]
        message destination
  | "forward-fails@example.com" -> (
      match Email.forward message destination with
      | () -> report "no error"
      | exception Js_error e -> report ("caught " ^ Promise.error_to_string e))
  | "reply@example.com" ->
      Email.reply message ~from:"support@example.com" ~to_:(Email.from message)
        "From: support@example.com\r\n\
         To: a@example.org\r\n\
         In-Reply-To: <1@example.org>\r\n\
         \r\n\
         thanks \xc3\xa9\r\n"
  | "reply-stream@example.com" ->
      let writer, raw = Stream.pipe () in
      Context.wait_until ctx (fun () ->
          Stream.Writer.write writer
            "From: support@example.com\r\nIn-Reply-To: <1@example.org>\r\n";
          Stream.Writer.write writer "\r\nstreamed \xc3\xa9\r\n";
          Stream.Writer.close writer);
      Email.reply_stream message ~from:"support@example.com"
        ~to_:(Email.from message) raw
  | "reject@example.com" -> Email.set_reject message "no thanks"
  | "raise@example.com" -> failwith "email failed"
  | "await@example.com" ->
      ignore (Promise.await (Timer.sleep 20));
      let status = Response.status (fetch "http://upstream.test/echo") in
      report (Printf.sprintf "upstream=%d" status)
  | other -> failwith ("no such test address: " ^ other)
