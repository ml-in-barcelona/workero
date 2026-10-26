open Workero
module R = Html_rewriter

let upstream = "http://upstream.test"
let sleep ms = Promise.await (Timer.sleep ms)
let rewrite rw html = Response.body_text (R.transform rw (Response.html html))
let set_class v el = R.Element.set_attribute el "class" v

let attributes () =
  let seen = Buffer.create 64 in
  let element el =
    Buffer.add_string seen
      (Printf.sprintf "tag=%s ns=%s attrs=%s has=%b/%b get=%s/%s"
         (R.Element.tag_name el)
         (R.Element.namespace_uri el)
         (String.concat ","
            (List.map (fun (k, v) -> k ^ "=" ^ v) (R.Element.attributes el)))
         (R.Element.has_attribute el "href")
         (R.Element.has_attribute el "nope")
         (Option.value (R.Element.get_attribute el "href") ~default:"none")
         (Option.value (R.Element.get_attribute el "nope") ~default:"none"));
    R.Element.remove_attribute el "id";
    R.Element.set_tag_name el "b";
    R.Element.on_end_tag el (fun tag ->
        Buffer.add_string seen (" end=" ^ R.End_tag.name tag);
        R.End_tag.set_name tag "strong";
        R.End_tag.before tag (R.Text "!"))
  in
  let out =
    rewrite (R.create () |> R.on ~element "a") {|<a id="x" href="/h">link</a>|}
  in
  Response.text (Buffer.contents seen ^ "\n" ^ out)

let edits () =
  let on selector f =
    rewrite
      (R.create () |> R.on ~element:f selector)
      {|<div><p>a</p><i>b</i></div>|}
  in
  let lines =
    [
      on "p" (fun el ->
          R.Element.before el (R.Text "<");
          R.Element.after el (R.Html ">");
          R.Element.prepend el (R.Text "[");
          R.Element.append el (R.Text "]"));
      on "p" (fun el -> R.Element.replace el (R.Html "<hr>"));
      on "p" (fun el -> R.Element.set_inner_content el (R.Text "new"));
      on "p" R.Element.remove;
      on "p" R.Element.remove_and_keep_content;
      on "p:first-child" (fun el -> R.Element.set_attribute el "n" "1");
      on "div > i" (fun el -> R.Element.set_attribute el "n" "2");
      on "p:not(.q)" (fun el -> R.Element.set_attribute el "n" "3");
      on "div i, p[x]" (fun el -> R.Element.set_attribute el "n" "4");
    ]
  in
  Response.text (String.concat "\n" lines)

let two_paragraphs () =
  Response.text
    (rewrite
       (R.create () |> R.on ~element:(set_class "mark") "p")
       "<p>one</p><div>two</div><p>three</p>")

let content () =
  let on c =
    rewrite
      (R.create ()
      |> R.on ~element:(fun el -> R.Element.set_inner_content el c) "p")
      "<p>old</p>"
  in
  Response.text (on (R.Text "<b>hi</b>") ^ "\n" ^ on (R.Html "<b>hi</b>"))

let stream_of ctx chunks =
  Option.get
    (Response.body
       (Response.stream ctx (fun w ->
            List.iter (Stream.Writer.write w) chunks;
            Stream.Writer.close w)))

let stream_content ctx =
  let on c =
    rewrite
      (R.create ()
      |> R.on ~element:(fun el -> R.Element.set_inner_content el (c ())) "p")
      "<p>old</p>"
  in
  let body () = Option.get (Response.body (Response.html "<b>hi</b>")) in
  Response.text
    (String.concat "\n"
       [
         on (fun () -> R.Text_stream (body ()));
         on (fun () -> R.Html_stream (body ()));
         on (fun () -> R.Html_stream (stream_of ctx [ "<i>"; "a"; "</i>" ]));
         on (fun () -> R.Text_response (Response.html "<b>hi</b>"));
         on (fun () -> R.Html_response (Response.html "<b>hi</b>"));
       ])

let document () =
  let seen = Buffer.create 64 in
  let note s = Buffer.add_string seen (s ^ ";") in
  let opt = Option.value ~default:"none" in
  let rw =
    R.create ()
    |> R.on_document
         ~doctype:(fun d ->
           note
             (Printf.sprintf "doctype=%s/%s/%s"
                (opt (R.Doctype.name d))
                (opt (R.Doctype.public_id d))
                (opt (R.Doctype.system_id d))))
         ~comments:(fun c ->
           note ("comment=" ^ R.Comment.text c);
           R.Comment.set_text c "changed")
         ~end_:(fun e ->
           R.Document_end.append e (R.Html "<footer>end</footer>"))
  in
  let out = rewrite rw "<!DOCTYPE html><!--c--><p>x</p>" in
  Response.text (Buffer.contents seen ^ "\n" ^ out)

let comments_and_text () =
  let out =
    rewrite
      (R.create ()
      |> R.on
           ~comments:(fun c -> R.Comment.replace c (R.Text "gone"))
           ~text:(fun t ->
             if R.Text_chunk.last_in_text_node t then
               R.Text_chunk.after t (R.Text "|"))
           "p")
      "<p>a<!--c-->b</p>"
  in
  Response.text out

let text_chunks () =
  let buf = Buffer.create 16 in
  let calls = ref 0 in
  let last = ref 0 in
  let big = String.make 100_000 'x' in
  let out =
    rewrite
      (R.create ()
      |> R.on
           ~text:(fun t ->
             incr calls;
             Buffer.add_string buf (R.Text_chunk.text t);
             if R.Text_chunk.last_in_text_node t then incr last)
           "p")
      ("<p>hello world</p><p>" ^ big ^ "</p>")
  in
  Response.text
    (Printf.sprintf "joined=%b last=%d multi=%b out=%d"
       (Buffer.contents buf = "hello world" ^ big)
       !last (!calls > !last) (String.length out))

let async_sleep () =
  let element el =
    sleep 20;
    set_class "after-sleep" el
  in
  Response.text
    (rewrite (R.create () |> R.on ~element "p") "<p>one</p><p>two</p>")

let async_fetch () =
  let element el =
    let res = fetch (upstream ^ "/echo") in
    R.Element.set_inner_content el (R.Text (Response.body_text res))
  in
  Response.text (rewrite (R.create () |> R.on ~element "p") "<p>x</p>")

let raises () =
  let element _ = failwith "boom-in-handler" in
  let res =
    R.transform (R.create () |> R.on ~element "p") (Response.html "<p>x</p>")
  in
  match Response.body_text res with
  | text -> Response.text ("no error: " ^ text)
  | exception Js_error e -> Response.text (Promise.error_to_string e)

let bad_selector () =
  match R.create () |> R.on ~element:ignore "p[" with
  | _ -> Response.text "no error"
  | exception Js_error _ -> Response.text "js_error"

let no_handler () =
  match R.on "p" (R.create ()) with
  | _ -> Response.text "no error"
  | exception Invalid_argument msg -> Response.text msg

let shared =
  R.create ()
  |> R.on ~element:(fun el -> R.Element.set_attribute el "shared" "1") "p"

let shared_twice () =
  let one = rewrite shared "<p>a</p>" in
  let two = rewrite shared "<p>b</p>" in
  Response.text (one ^ "\n" ^ two)

let handled = ref 0

let large () =
  handled := 0;
  let body =
    let b = Buffer.create (1 lsl 20) in
    for _ = 1 to 60_000 do
      Buffer.add_string b "<p>xxxxxxxxxxxx</p>\n"
    done;
    Buffer.contents b
  in
  R.transform
    (R.create () |> R.on ~element:(fun _ -> incr handled) "p")
    (Response.html body)

let interleave () =
  let log = Buffer.create 32 in
  let element el =
    let id =
      R.Element.tag_name el
      ^ Option.value (R.Element.get_attribute el "id") ~default:""
    in
    Buffer.add_string log ("s" ^ id ^ " ");
    sleep 20;
    Buffer.add_string log ("e" ^ id ^ " ")
  in
  let _ =
    rewrite
      (R.create () |> R.on ~element "p")
      {|<p id="1">a</p><p id="2">b</p><p id="3">c</p>|}
  in
  Response.text (Buffer.contents log)

let handle req _env ctx =
  match URL.path (Request.url req) with
  | "/html/two" -> Some (two_paragraphs ())
  | "/html/attributes" -> Some (attributes ())
  | "/html/edits" -> Some (edits ())
  | "/html/content" -> Some (content ())
  | "/html/stream-content" -> Some (stream_content ctx)
  | "/html/document" -> Some (document ())
  | "/html/comments-text" -> Some (comments_and_text ())
  | "/html/chunks" -> Some (text_chunks ())
  | "/html/async-sleep" -> Some (async_sleep ())
  | "/html/async-fetch" -> Some (async_fetch ())
  | "/html/raises" -> Some (raises ())
  | "/html/bad-selector" -> Some (bad_selector ())
  | "/html/no-handler" -> Some (no_handler ())
  | "/html/shared" -> Some (shared_twice ())
  | "/html/large" -> Some (large ())
  | "/html/interleave" -> Some (interleave ())
  | "/html/state" -> Some (Response.text (string_of_int !handled))
  | _ -> None
