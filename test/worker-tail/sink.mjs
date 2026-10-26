const store = { items: [], after: [], stream: [] };

export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (request.method === "POST") {
      store[pathname.slice(1)].push(await request.json());
      return new Response("stored");
    }
    if (request.method === "DELETE") {
      for (const list of Object.values(store)) list.length = 0;
      return new Response("cleared");
    }
    return Response.json(store);
  },
};
