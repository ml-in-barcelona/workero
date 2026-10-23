const items = [];
const after = [];

export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (request.method === "POST") {
      const body = await request.json();
      (pathname === "/after" ? after : items).push(body);
      return new Response("stored");
    }
    if (request.method === "DELETE") {
      items.length = 0;
      after.length = 0;
      return new Response("cleared");
    }
    return Response.json({ items, after });
  },
};
