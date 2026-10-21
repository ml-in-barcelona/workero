import { runCases } from "./lib.mjs";

const JSON_TYPE = "application/json; charset=utf-8";
const post = (path, body) => [
  `http://test${path}`,
  { method: "POST", body },
];

const cases = [
  {
    name: "GET with query",
    request: ["http://test/hello?name=ocaml"],
    status: 200,
    body: "hello, ocaml\n",
  },
  {
    name: "POST body",
    request: ["http://test/echo", { method: "POST", body: "ping" }],
    status: 200,
    body: "ping",
  },
  {
    name: "request header",
    request: ["http://test/header", { headers: { "x-test": "abc" } }],
    status: 200,
    body: "abc\n",
  },
  {
    name: "response status and headers",
    request: ["http://test/status"],
    status: 201,
    body: "made\n",
    headers: { "x-made": "yes" },
  },
  {
    name: "env var",
    request: ["http://test/env"],
    status: 200,
    body: "from test config\n",
  },
  {
    name: "method GET",
    request: ["http://test/method"],
    status: 200,
    body: "GET",
  },
  {
    name: "method POST",
    request: ["http://test/method", { method: "POST", body: "x" }],
    status: 200,
    body: "POST",
  },
  {
    name: "method DELETE",
    request: ["http://test/method", { method: "DELETE" }],
    status: 200,
    body: "DELETE",
  },
  {
    name: "method PATCH",
    request: ["http://test/method", { method: "PATCH", body: "x" }],
    status: 200,
    body: "PATCH",
  },
  {
    name: "method OPTIONS",
    request: ["http://test/method", { method: "OPTIONS" }],
    status: 200,
    body: "OPTIONS",
  },
  {
    name: "method other",
    request: ["http://test/method", { method: "PURGE" }],
    status: 200,
    body: "other:PURGE",
  },
  {
    name: "headers list",
    request: [
      "http://test/headers",
      { headers: { "X-B": "2", "x-a": "1", accept: "*/*" } },
    ],
    status: 200,
    body: "x-a=1;x-b=2",
  },
  {
    name: "repeated header",
    request: [
      "http://test/headers",
      {
        headers: [
          ["x-d", "p"],
          ["x-d", "q"],
        ],
      },
    ],
    status: 200,
    body: "x-d=p, q",
  },
  {
    name: "bytes body is not UTF-8",
    request: [
      "http://test/bytes",
      { method: "POST", body: new Uint8Array([255, 254, 0, 128, 10]) },
    ],
    status: 200,
    bodyBytes: [255, 254, 0, 128, 10],
    headers: { "content-type": "application/octet-stream", "x-length": "5" },
  },
  {
    name: "cf absent",
    request: ["http://test/cf"],
    status: 200,
    body: "country=none city=none colo=none asn=none",
  },
  {
    name: "cf present",
    request: [
      "http://test/cf",
      { cf: { country: "ES", city: "Barcelona", colo: "BCN", asn: 1234 } },
    ],
    status: 200,
    body: "country=ES city=Barcelona colo=BCN asn=1234",
  },
  {
    name: "empty body with a null body status",
    request: ["http://test/no-content"],
    status: 204,
    body: "",
  },
  {
    name: "html",
    request: ["http://test/html"],
    status: 200,
    body: "<p>hi</p>",
    headers: { "content-type": "text/html; charset=utf-8" },
  },
  {
    name: "html keeps a given content-type",
    request: ["http://test/html-type"],
    status: 404,
    body: "<p>gone</p>",
    headers: { "content-type": "text/html; charset=latin1" },
  },
  {
    name: "make sends raw bytes",
    request: ["http://test/make"],
    status: 202,
    bodyBytes: [0, 137, 80, 78, 71, 255],
    headers: { "content-type": "image/png", "x-a": "1" },
  },
  {
    name: "redirect",
    request: ["http://test/redirect", { redirect: "manual" }],
    status: 302,
    headers: { location: "http://test/hello" },
  },
  {
    name: "redirect with status",
    request: ["http://test/redirect-301", { redirect: "manual" }],
    status: 301,
    headers: { location: "http://test/hello" },
  },
  {
    name: "redirect with a bad status",
    request: ["http://test/redirect-bad"],
    throws: "Invalid_argument",
  },
  {
    name: "to_js and of_js",
    request: ["http://test/js"],
    status: 200,
    body: "GET;from test config;function",
  },
  {
    name: "Response.of_js",
    request: ["http://test/js-response"],
    status: 202,
    body: "raw",
  },
  {
    name: "outgoing fetch",
    request: ["http://test/fetch"],
    status: 200,
    body: "status=203 upstream=yes body=PUT|1,2|payload",
  },
  {
    name: "outgoing fetch defaults",
    request: ["http://test/fetch-get"],
    status: 200,
    body: "GET|null,null|",
  },
  {
    name: "outgoing fetch with a bytes body",
    request: [
      "http://test/fetch-raw",
      { method: "POST", body: new Uint8Array([255, 0, 254, 128]) },
    ],
    status: 200,
    bodyBytes: [255, 0, 254, 128],
  },
  {
    name: "outgoing response headers and bytes",
    request: ["http://test/fetch-headers"],
    status: 200,
    bodyBytes: [0, 255, 128, 10],
    headers: { "x-upstream-headers": "x-one=1;x-two=2" },
  },
  {
    name: "outgoing fetch failure caught",
    request: ["http://test/fetch-caught"],
    status: 502,
    bodyIncludes: "upstream down",
  },
  {
    name: "outgoing fetch failure raises",
    request: ["http://test/fetch-reject"],
    throws: "upstream down",
  },
  { name: "KV get of a missing key", request: ["http://test/kv/get?k=kv-a"], status: 200, body: "none" },
  { name: "KV put", request: ["http://test/kv/put?k=kv-a&v=1&ttl=120"], status: 200, body: "ok" },
  { name: "KV get", request: ["http://test/kv/get?k=kv-a"], status: 200, body: "1" },
  {
    name: "KV round trips UTF-8",
    request: [`http://test/kv/put?k=kv-u&v=${encodeURIComponent("h\u00e9llo")}`],
    status: 200,
    body: "ok",
  },
  {
    name: "KV get UTF-8",
    request: ["http://test/kv/get?k=kv-u"],
    status: 200,
    body: "h\u00e9llo",
  },
  { name: "KV put p-2", request: ["http://test/kv/put?k=kv-p-2&v=x"], status: 200, body: "ok" },
  { name: "KV put p-1", request: ["http://test/kv/put?k=kv-p-1&v=x"], status: 200, body: "ok" },
  { name: "KV list with prefix", request: ["http://test/kv/list?prefix=kv-p-"], status: 200, body: "kv-p-1,kv-p-2" },
  ...[1, 2, 3, 4, 5, 6, 7].map((n) => ({
    name: `KV put q-${n}`,
    request: [`http://test/kv/put?k=kv-q-${n}&v=x`],
    status: 200,
    body: "ok",
  })),
  {
    name: "KV list follows the cursor past one page",
    request: ["http://test/kv/list?prefix=kv-q-"],
    status: 200,
    body: "kv-q-1,kv-q-2,kv-q-3,kv-q-4,kv-q-5,kv-q-6,kv-q-7",
  },
  {
    name: "KV list",
    request: ["http://test/kv/list"],
    status: 200,
    body: "kv-a,kv-p-1,kv-p-2,kv-q-1,kv-q-2,kv-q-3,kv-q-4,kv-q-5,kv-q-6,kv-q-7,kv-u",
  },
  { name: "KV delete", request: ["http://test/kv/delete?k=kv-a"], status: 200, body: "ok" },
  { name: "KV get after delete", request: ["http://test/kv/get?k=kv-a"], status: 200, body: "none" },
  { name: "KV delete of a missing key", request: ["http://test/kv/delete?k=kv-a"], status: 200, body: "ok" },
  { name: "R2 get of a missing key", request: ["http://test/r2/get?k=r2-a"], status: 404, body: "none" },
  {
    name: "R2 put",
    request: ["http://test/r2/put?k=r2-a&type=image/png", { method: "POST", body: new Uint8Array([255, 0, 128]) }],
    status: 200,
    body: "ok",
  },
  { name: "R2 get bytes", request: ["http://test/r2/get?k=r2-a"], status: 200, bodyBytes: [255, 0, 128] },
  {
    name: "R2 head",
    request: ["http://test/r2/head?k=r2-a"],
    status: 200,
    body: "size=3 etag=etag-r2-a-3 type=image/png",
  },
  {
    name: "R2 put without content type",
    request: ["http://test/r2/put?k=r2-b", { method: "POST", body: "hello" }],
    status: 200,
    body: "ok",
  },
  { name: "R2 head without content type", request: ["http://test/r2/head?k=r2-b"], status: 200, body: "size=5 etag=etag-r2-b-5 type=none" },
  { name: "R2 head of a missing key", request: ["http://test/r2/head?k=r2-z"], status: 404, body: "none" },
  { name: "R2 delete", request: ["http://test/r2/delete?k=r2-a"], status: 200, body: "ok" },
  { name: "R2 get after delete", request: ["http://test/r2/get?k=r2-a"], status: 404, body: "none" },
  { name: "R2 delete of a missing key", request: ["http://test/r2/delete?k=r2-a"], status: 200, body: "ok" },
  { name: "Cache miss", request: ["http://test/cache/match?k=http://x.test/a"], status: 404, body: "miss" },
  {
    name: "Cache put",
    request: ["http://test/cache/put?k=http://x.test/a", { method: "POST", body: "hello cache" }],
    status: 200,
    body: "ok",
  },
  { name: "Cache match", request: ["http://test/cache/match?k=http://x.test/a"], status: 200, body: "200 yes hello cache" },
  { name: "Cache delete", request: ["http://test/cache/delete?k=http://x.test/a"], status: 200, body: "true" },
  { name: "Cache delete of a missing key", request: ["http://test/cache/delete?k=http://x.test/a"], status: 200, body: "false" },
  { name: "Cache match after delete", request: ["http://test/cache/match?k=http://x.test/a"], status: 404, body: "miss" },
  {
    name: "D1 round trips every value type",
    request: ["http://test/d1/types"],
    status: 200,
    body: "create=0 inserted=1 deleted=1\nn=i:42,r=f:1.5,s=t:h\u00e9llo,b=b:00ff0a,z=null",
  },
  { name: "D1 synchronous JS throw", request: ["http://test/d1/sync-throw"], status: 502, body: "caught TypeError: D1_ERROR: no SQL statement" },
  {
    name: "D1 integers above 2^31 and up to 2^53",
    request: ["http://test/d1/ints"],
    status: 200,
    body: "n=i:-5;n=i:3000000000;n=i:9007199254740992",
  },
  {
    name: "D1 refuses an integer above 2^53",
    request: ["http://test/d1/int-too-big"],
    status: 400,
    body: "Workero.Sql_value.to_js: 9007199254740993 is beyond 2^53",
  },
  {
    name: "D1 keeps duplicate and numeric-looking column names in SELECT order",
    request: ["http://test/d1/columns"],
    status: 200,
    body: "id=i:1,id=i:2,10=i:3,2=i:4",
  },
  { name: "D1 query without params", request: ["http://test/d1/no-params"], status: 200, body: "one=i:1,two=t:x" },
  { name: "D1 SQL error", request: ["http://test/d1/error"], status: 502, bodyIncludes: "Error: " }
  ,{ name: "D1 SQL error has the SQLite message", request: ["http://test/d1/error"], status: 502, bodyIncludes: "syntax error" },
  {
    name: "KV list refuses an incomplete page without a cursor",
    request: ["http://test/kv/list-broken"],
    status: 502,
    bodyIncludes: "without a cursor",
  },
  {
    name: "a variable is not a binding",
    request: ["http://test/binding/shape?name=GREETING"],
    status: 200,
    body: [
      'Workero.KV.of_env: binding "GREETING" is a string, not a KV namespace',
      'Workero.R2.of_env: binding "GREETING" is a string, not an R2 bucket',
      'Workero.D1.of_env: binding "GREETING" is a string, not a D1 database',
    ].join("\n"),
  },
  {
    name: "an inherited property is not a binding",
    request: ["http://test/binding/shape?name=toString"],
    status: 200,
    body: ["KV", "R2", "D1"].map((k) => `Workero.${k}.of_env: binding "toString" not found`).join("\n"),
  },
  {
    name: "a binding of another kind",
    request: ["http://test/binding/shape?name=KV"],
    status: 200,
    body: [
      "ok",
      'Workero.R2.of_env: binding "KV" is an object without method head, not an R2 bucket',
      'Workero.D1.of_env: binding "KV" is an object without method prepare, not a D1 database',
    ].join("\n"),
  },
  {
    name: "missing bindings",
    request: ["http://test/binding/missing"],
    status: 200,
    body: 'Workero.KV.of_env: binding "NOPE" not found\nWorkero.R2.of_env: binding "NOPE" not found\nWorkero.D1.of_env: binding "NOPE" not found',
  },
  { name: "resolve of a promise, awaited twice", request: ["http://test/promise/nested"], status: 200, body: "1" },
  { name: "make resolved with a thenable", request: ["http://test/promise/make-thenable"], status: 200, body: "7" },
  { name: "of_js with a decoder", request: ["http://test/promise/of-js"], status: 200, body: "5" },
  {
    name: "of_js with the wrong decoder",
    request: ["http://test/promise/of-js-wrong-decoder"],
    status: 502,
    bodyIncludes: "Workero.Decode: expected string, got number",
  },
  { name: "OCaml exception after an await", request: ["http://test/promise/raise-after-await"], throws: "Failed" },
  { name: "Js_error re-raised after an await", request: ["http://test/promise/rethrow"], throws: "again" },
  { name: "Js_error carries the original reason", request: ["http://test/promise/error-payload"], status: 200, body: "42" },
  { name: "map and bind", request: ["http://test/promise/map-bind"], status: 200, body: "9" },
  { name: "all keeps order", request: ["http://test/promise/all"], status: 200, body: "1,2,3" },
  { name: "race", request: ["http://test/promise/race"], status: 200, body: "fast" },
  { name: "any", request: ["http://test/promise/any"], status: 200, body: "ok" },
  { name: "any, all rejected", request: ["http://test/promise/any-rejected"], status: 502, bodyIncludes: "AggregateError" },
  { name: "all_settled", request: ["http://test/promise/all-settled"], status: 200, body: "ok:1,error:Error: no" },
  {
    name: "OCaml exceptions in map, bind and make keep their type",
    request: ["http://test/promise/callback-exceptions"],
    status: 200,
    body: "map: Failure x;bind: Invalid_argument y;make: Not_found",
  },
  { name: "an OCaml exception in map reaches the runtime", request: ["http://test/promise/map-escapes"], throws: 'Failure("boom")' },
  { name: "a rejection that cannot be printed", request: ["http://test/promise/unprintable"], status: 200, body: "[object Object]" },
  { name: "unknown route", request: ["http://test/nope"], status: 404 },
  { name: "OCaml exception", request: ["http://test/fail"], throws: "Failed" },
  {
    name: "rejected promise",
    request: ["http://test/reject"],
    throws: "nope",
  },
  {
    name: "await a timer",
    request: ["http://test/sleep"],
    status: 200,
    body: "slept\n",
  },
  {
    name: "json echo valid JSON",
    request: post("/json/echo", '{"a":[1,2.5,null,true],"b":{"c":"d"}}'),
    status: 200,
    body: '{"a":[1,2.5,null,true],"b":{"c":"d"}}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "json unicode round trip",
    request: post("/json/echo", '{"s":"héllo ñ 日本語 😀 \\u00e9"}'),
    status: 200,
    body: '{"s":"héllo ñ 日本語 😀 é"}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "json invalid JSON",
    request: post("/json/echo", '{"a":'),
    status: 400,
    body: '{"error":"Line 1, bytes 4-5:\\nUnexpected end of input"}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "json empty body",
    request: post("/json/echo", ""),
    status: 400,
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "json decode a record, ignore extra fields",
    request: post("/json/user", '{"name":"Ana","age":30,"extra":1}'),
    status: 200,
    body: '{"name":"Ana","age":30}',
    headers: { "content-type": JSON_TYPE },
  },
  {
    name: "json decode type mismatch",
    request: post("/json/user", '{"name":"Ana","age":"x"}'),
    status: 422,
    body: '{"error":"expected int but got string: \\"x\\""}',
  },
  {
    name: "json decode invalid JSON",
    request: post("/json/user", "nope"),
    status: 422,
  },
  {
    name: "json uncaught parse error",
    request: post("/json/raise", "{bad"),
    throws: "Of_string_error",
  },
  {
    name: "json custom status and headers",
    request: ["http://test/json/custom"],
    status: 201,
    body: "[1,null]",
    headers: { "content-type": "application/vnd.api+json", "x-a": "b" },
  },
  {
    name: "request path keeps percent-encoding, query_string is raw",
    request: ["http://test/req/path/a%2Fb/%E2%9C%93?x=1%2B2&y"],
    status: 200,
    body: "path=/req/path/a%2Fb/%E2%9C%93 query=x=1%2B2&y",
  },
  {
    name: "request path without query",
    request: ["http://test/req/path"],
    status: 200,
    body: "path=/req/path query=",
  },
  {
    name: "request header_all joins repeated request headers",
    request: [
      "http://test/req/header-all",
      {
        headers: [
          ["x-m", "1"],
          ["x-m", "2"],
          ["cookie", "a=1"],
          ["cookie", "b=2"],
        ],
      },
    ],
    status: 200,
    body: "x-m=1, 2 cookie=a=1, b=2 header=a=1, b=2 none=0",
  },
  {
    name: "request clone: both copies read the body",
    request: post("/req/clone", "same"),
    status: 200,
    body: "same|same",
  },
  {
    name: "response header_all keeps each set-cookie",
    request: ["http://test/res/cookies"],
    status: 200,
    body: "2:a=1; Path=/|b=2; Expires=Wed, 21 Oct 2026 07:28:00 GMT",
  },
  { name: "json unknown route", request: ["http://test/json/nope"], status: 404 },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
  const background = async (path) =>
    (await env.WORKER.fetch(`http://test/background/${path}`)).text();
  const started = await background("start?v=ran");
  if (started !== "started") failures.push(`background start: ${started}`);
  let result = "unset";
  for (let i = 0; i < 100 && result !== "done:ran"; i++) {
    await new Promise((r) => setTimeout(r, 20));
    result = await background("read");
  }
  if (result !== "done:ran") failures.push(`wait_until did not run: ${result}`);
  console.log(`${result === "done:ran" ? "ok" : "FAIL"} - wait_until runs after the response`);
  await background("fail");
  await new Promise((r) => setTimeout(r, 100));
  const after = await (await env.WORKER.fetch("http://test/hello")).text();
  if (after !== "hello, world\n") failures.push(`after failing wait_until: ${after}`);
  console.log(`${after === "hello, world\n" ? "ok" : "FAIL"} - request after a failing wait_until`);
  const concurrent = await Promise.all(
    Array.from({ length: 20 }, (_, i) =>
      env.WORKER.fetch(`http://test/hello?name=n${i}`).then((r) => r.text()),
    ),
  );
  concurrent.forEach((b, i) => {
    if (b !== `hello, n${i}\n`) failures.push(`concurrent ${i}: ${JSON.stringify(b)}`);
  });
  console.log(`${concurrent.length} concurrent requests`);
  const expected = "cron=*/5 * * * * time=1700000000000 env=from test config upstream=203";
  await env.WORKER.scheduled({ cron: "*/5 * * * *", scheduledTime: 1700000000000 });
  const ran = await (await env.WORKER.fetch("http://test/scheduled/read")).text();
  if (ran !== expected) failures.push(`scheduled: ${JSON.stringify(ran)}`);
  console.log(`${ran === expected ? "ok" : "FAIL"} - scheduled handler runs and awaits`);
  let scheduledError = "";
  try {
    await env.WORKER.scheduled({ cron: "fail", scheduledTime: 1 });
  } catch (error) {
    scheduledError = String(error);
  }
  const rejected = scheduledError.includes("Failed");
  if (!rejected) failures.push(`scheduled exception: ${JSON.stringify(scheduledError)}`);
  console.log(`${rejected ? "ok" : "FAIL"} - scheduled exception rejects`);
  const kept = await (await env.WORKER.fetch("http://test/scheduled/read")).text();
  if (kept !== expected) failures.push(`after failing scheduled: ${JSON.stringify(kept)}`);
  console.log(`${kept === expected ? "ok" : "FAIL"} - fetch after a failing scheduled`);
};
