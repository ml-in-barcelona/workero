const expect = (condition, message) => {
  if (!condition) throw new Error(message);
  console.log(`ok - ${message}`);
};

const check = async (env, name, path, options, status, body, headers = {}) => {
  const response = await env[name].fetch(`http://test${path}`, options);
  expect(response.status === status, `${name} ${path}: status ${status}`);
  expect((await response.text()) === body, `${name} ${path}: body ${JSON.stringify(body)}`);
  for (const [header, value] of Object.entries(headers))
    expect(response.headers.get(header) === value, `${name} ${path}: ${header} ${value}`);
};

export default {
  async test(_controller, env) {
    await check(env, "README", "/", {}, 200, "Hello from OCaml on Cloudflare Workers\n");
    await check(env, "TEMPLATE", "/", {}, 200, "Hello from OCaml on Cloudflare Workers\n");
    await check(env, "TEMPLATE", "/echo", { method: "POST", body: "ping" }, 200, "ping");
    await check(env, "TEMPLATE", "/env", {}, 200, "hello from vars\n");
    await check(env, "REQUESTS", "/hello?name=Ada", {}, 200, "hello, Ada\n");
    await check(env, "REQUESTS", "/echo", { method: "POST", body: "payload" }, 200, "payload");
    await check(env, "STREAMS", "/", { method: "POST", body: "hello" }, 200, "5 bytes\n");
    const form = new FormData();
    form.append("avatar", new File(["hello"], "avatar.txt"));
    await check(env, "FORMS", "/", { method: "POST", body: form }, 200, "avatar.txt: 5 bytes\n");
    await check(env, "FORMS", "/", { method: "POST", body: "no file" }, 400, "not a form\n");
    await check(env, "JSON", "/", { method: "POST", body: '{"name":"Ada","age":36}' },
      200, '{"name":"Ada","age":36}', { "content-type": "application/json; charset=utf-8" });
    await check(env, "JSON", "/", { method: "POST", body: '{"name":"Ada","age":"bad"}' },
      400, '{"error":"expected int but got string: \\"bad\\""}',
      { "content-type": "application/json; charset=utf-8" });

    for (const [scenario, status, body, headers, cached] of [
      ["ok", 200, "origin body", { "x-origin": "kept", "cache-control": "public, max-age=60" }, true],
      ["status", 503, "unavailable", { "x-origin": "unavailable" }, false],
      ["cookie", 200, "private", { "x-origin": "cookie", "set-cookie": "session=one" }, false],
      ["policy", 200, "policy", { "x-origin": "policy", "cache-control": "private" }, false],
      ["vary", 200, "vary", { "x-origin": "vary", vary: "*" }, false],
    ]) {
      await env.ORIGIN.fetch("http://origin/control", { method: "POST", body: scenario });
      const url = `http://test/${scenario}`;
      for (let i = 0; i < 2; i++) {
        const response = await env.CACHE.fetch(url);
        expect(response.status === status, `cache ${scenario}: upstream status`);
        expect((await response.text()) === body, `cache ${scenario}: upstream body`);
        for (const [header, value] of Object.entries(headers))
          expect(response.headers.get(header) === value, `cache ${scenario}: ${header}`);
        if (!cached) expect(response.headers.get("cache-control") === (headers["cache-control"] ?? null),
          `cache ${scenario}: no new cache policy`);
      }
      const hits = Number(await (await env.ORIGIN.fetch("http://origin/hits")).text());
      expect(hits === (cached ? 1 : 2), `cache ${scenario}: origin called ${cached ? 1 : 2} times`);
    }
    await env.ORIGIN.fetch("http://origin/control", { method: "POST", body: "error" });
    for (let i = 0; i < 2; i++) {
      let error;
      try { await env.CACHE.fetch("http://test/error"); } catch (caught) { error = String(caught); }
      expect(error?.includes("documented origin failure"), "cache: origin failure propagates");
    }
    expect((await (await env.ORIGIN.fetch("http://origin/hits")).text()) === "2",
      "cache: origin failure is not cached");
    await check(env, "CACHE", "/post", { method: "POST", body: "no" }, 405, "method not allowed\n");
  },
};
