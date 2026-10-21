const store = new Map();

const parse = (bytes) => {
  const text = new TextDecoder("latin1").decode(bytes);
  const end = text.indexOf("\r\n\r\n");
  const [statusLine, ...lines] = text.slice(0, end).split("\r\n");
  const headers = lines.map((line) => {
    const colon = line.indexOf(":");
    return [line.slice(0, colon), line.slice(colon + 1).trim()];
  });
  return { status: Number(statusLine.split(" ")[1]), headers, body: bytes.slice(end + 4) };
};

export default {
  async fetch(request) {
    switch (request.method) {
      case "PUT":
        store.set(request.url, parse(new Uint8Array(await request.arrayBuffer())));
        return new Response(null, { status: 204 });
      case "GET": {
        const entry = store.get(request.url);
        if (!entry)
          return new Response("miss", { status: 504, headers: { "cf-cache-status": "MISS" } });
        return new Response(entry.body, {
          status: entry.status,
          headers: [...entry.headers, ["cf-cache-status", "HIT"]],
        });
      }
      case "PURGE":
        return new Response(null, { status: store.delete(request.url) ? 200 : 404 });
    }
    return new Response("unsupported", { status: 400 });
  },
};
