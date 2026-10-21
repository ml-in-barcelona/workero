const objects = new Map();
const encoder = new TextEncoder();

const metadataOf = (name, { value, httpFields }) => ({
  name,
  version: "v1",
  size: value.length,
  etag: `etag-${name}-${value.length}`,
  uploaded: 0,
  httpFields,
  customFields: [],
  checksums: {},
});

const reply = (metadata, value = new Uint8Array()) => {
  const head = encoder.encode(JSON.stringify(metadata));
  const body = new Uint8Array(head.length + value.length);
  body.set(head);
  body.set(value, head.length);
  return new Response(body, { headers: { "cf-r2-metadata-size": String(head.length) } });
};

const notFound = () =>
  new Response(null, {
    status: 404,
    headers: { "cf-r2-error": JSON.stringify({ message: "The specified key does not exist.", version: 1, v4code: 10007 }) },
  });

export default {
  async fetch(request) {
    const header = request.headers.get("cf-r2-request");
    if (header !== null) {
      const { method, object } = JSON.parse(header);
      const entry = objects.get(object);
      if (entry === undefined) return notFound();
      return reply(metadataOf(object, entry), method === "get" ? entry.value : undefined);
    }
    const size = Number(request.headers.get("cf-r2-metadata-size"));
    const bytes = new Uint8Array(await request.arrayBuffer());
    const { method, object, httpFields } = JSON.parse(new TextDecoder().decode(bytes.slice(0, size)));
    if (method === "delete") {
      objects.delete(object);
      return reply({});
    }
    const entry = { value: bytes.slice(size), httpFields: httpFields ?? {} };
    objects.set(object, entry);
    return reply(metadataOf(object, entry));
  },
};
