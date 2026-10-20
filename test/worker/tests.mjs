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
    throws: "Js_error",
  },
  { name: "unknown route", request: ["http://test/nope"], status: 404 },
  { name: "OCaml exception", request: ["http://test/fail"], throws: "Failed" },
  {
    name: "rejected promise",
    request: ["http://test/reject"],
    throws: "Js_error",
  },
  {
    name: "await a timer",
    request: ["http://test/sleep"],
    status: 200,
    body: "slept\n",
  },
];

const sameBytes = (actual, expected) =>
  actual.length === expected.length && expected.every((b, i) => actual[i] === b);

const report = (name, problems, failures) => {
  if (problems.length) failures.push(`${name}: ${problems.join("; ")}`);
  console.log(`${problems.length ? "FAIL" : "ok"} - ${name}`);
};

export default {
  async test(_controller, env) {
    const failures = [];
    for (const c of cases) {
      const problems = [];
      let response;
      let body;
      let bytes;
      try {
        response = await env.WORKER.fetch(...c.request);
        bytes = new Uint8Array(await response.arrayBuffer());
        body = new TextDecoder().decode(bytes);
      } catch (error) {
        if (c.throws === undefined || !String(error).includes(c.throws))
          problems.push(`threw ${error}`);
        report(c.name, problems, failures);
        continue;
      }
      if (c.throws !== undefined) problems.push("did not throw");
      if (response.status !== c.status)
        problems.push(`status ${response.status}, expected ${c.status}`);
      if (c.body !== undefined && body !== c.body)
        problems.push(`body ${JSON.stringify(body)}, expected ${JSON.stringify(c.body)}`);
      if (c.bodyIncludes !== undefined && !body.includes(c.bodyIncludes))
        problems.push(`body ${JSON.stringify(body)} lacks ${JSON.stringify(c.bodyIncludes)}`);
      if (c.bodyBytes !== undefined && !sameBytes(bytes, c.bodyBytes))
        problems.push(`bytes ${[...bytes]}, expected ${c.bodyBytes}`);
      for (const [k, v] of Object.entries(c.headers ?? {}))
        if (response.headers.get(k) !== v)
          problems.push(`header ${k} is ${response.headers.get(k)}, expected ${v}`);
      report(c.name, problems, failures);
    }
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
    if (failures.length) throw new Error(failures.join("\n"));
  },
};
