const store = new Map();
const pageLimit = 3;

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const key = decodeURIComponent(url.pathname.slice(1));
    switch (request.method) {
      case "GET": {
        if (key === "") {
          const prefix = url.searchParams.get("prefix") ?? "";
          if (prefix === "kv-broken-")
            return Response.json({ keys: [{ name: "kv-broken-1" }], list_complete: false });
          const limit = Math.min(Number(url.searchParams.get("limit") ?? pageLimit), pageLimit);
          const start = Number(url.searchParams.get("cursor") ?? 0);
          const names = [...store.keys()].filter((name) => name.startsWith(prefix)).sort();
          const page = names.slice(start, start + limit);
          const complete = start + limit >= names.length;
          return Response.json({
            keys: page.map((name) => ({ name })),
            list_complete: complete,
            cursor: complete ? undefined : String(start + limit),
            cacheStatus: null,
          });
        }
        if (!store.has(key))
          return new Response("Not Found", { status: 404, headers: { "CF-KV-Status": "404" } });
        return new Response(store.get(key).value);
      }
      case "PUT":
        store.set(key, {
          value: await request.text(),
          ttl: url.searchParams.get("expiration_ttl"),
        });
        return new Response("OK");
      case "DELETE":
        store.delete(key);
        return new Response("OK");
    }
    return new Response("unsupported", { status: 400 });
  },
};
