import { report, runCases } from "./lib.mjs";

const get = (name, path, body) => ({
  name: `Html_rewriter: ${name}`,
  request: [`http://test/html/${path}`],
  status: 200,
  body,
});

const cases = [
  get("an element handler rewrites every match", "two",
    '<p class="mark">one</p><div>two</div><p class="mark">three</p>'),
  get("Element reads attributes and tag names, End_tag renames", "attributes", [
    "tag=a ns=http://www.w3.org/1999/xhtml attrs=id=x,href=/h has=true/false get=/h/none end=b",
    '<b href="/h">link!</strong>',
  ].join("\n")),
  get("Element edit functions and selectors", "edits", [
    "<div>&lt;<p>[a]</p>><i>b</i></div>",
    "<div><hr><i>b</i></div>",
    "<div><p>new</p><i>b</i></div>",
    "<div><i>b</i></div>",
    "<div>a<i>b</i></div>",
    '<div><p n="1">a</p><i>b</i></div>',
    '<div><p>a</p><i n="2">b</i></div>',
    '<div><p n="3">a</p><i>b</i></div>',
    '<div><p>a</p><i n="4">b</i></div>',
  ].join("\n")),
  get("Text content is escaped and Html content is markup", "content",
    "<p>&lt;b&gt;hi&lt;/b&gt;</p>\n<p><b>hi</b></p>"),
  get("a Stream or a Response is content, escaped or as markup", "stream-content", [
    "<p>&lt;b&gt;hi&lt;/b&gt;</p>",
    "<p><b>hi</b></p>",
    "<p><i>a</i></p>",
    "<p>&lt;b&gt;hi&lt;/b&gt;</p>",
    "<p><b>hi</b></p>",
  ].join("\n")),
  get("on_document sees the doctype and comments and appends at the end", "document",
    "doctype=html/none/none;comment=c;\n<!DOCTYPE html><!--changed--><p>x</p><footer>end</footer>"),
  get("comment and text handlers run inside a matching element", "comments-text",
    "<p>a|goneb|</p>"),
  get("a text node arrives in chunks that join to the full text", "chunks",
    "joined=true last=2 multi=true out=100025"),
  get("a handler may sleep before it edits", "async-sleep",
    '<p class="after-sleep">one</p><p class="after-sleep">two</p>'),
  get("a handler may fetch before it edits", "async-fetch",
    "<p>GET|null,null|</p>"),
  get("two handlers that sleep run one after the other, in document order", "interleave",
    "sp1 ep1 sp2 ep2 sp3 ep3 "),
  get("an exception in a handler errors the body with its text", "raises",
    'Error: Failure("boom-in-handler")'),
  get("a bad selector raises Js_error at on", "bad-selector", "js_error"),
  get("on without a handler raises Invalid_argument", "no-handler",
    "Workero.Html_rewriter.on: no handler given"),
  get("a toplevel rewriter transforms two responses", "shared",
    '<p shared="1">a</p>\n<p shared="1">b</p>'),
];

const largeCase = async (env, failures) => {
  const problems = [];
  const res = await env.WORKER.fetch("http://test/html/large");
  const body = await res.text();
  const state = await (await env.WORKER.fetch("http://test/html/state")).text();
  if (body.split("<p>").length - 1 !== 60000) problems.push(`body has ${body.length} bytes`);
  if (state !== "60000") problems.push(`handler ran ${state} times`);
  report("Html_rewriter: a 1.2 MB body streams through transform", problems, failures);
};

export default async (env, failures) => {
  await runCases(env, cases, failures);
  await largeCase(env, failures);
};
