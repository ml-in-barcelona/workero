import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const source = pathToFileURL(process.argv[2]).href;
let n = 0;

const exported = async (registered) => {
  globalThis.__workero = registered;
  return (await import(`${source}?case=${n++}`)).default;
};

const noop = () => "called";

let handlers = await exported({ fetch: noop, scheduled: noop });
assert.deepEqual(Object.keys(handlers).sort(), ["fetch", "scheduled"]);

handlers = await exported({ scheduled: noop });
assert.deepEqual(Object.keys(handlers), ["scheduled"]);
assert.equal(handlers.scheduled(), "called");

handlers = await exported({ fetch: noop });
assert.deepEqual(Object.keys(handlers), ["fetch"]);

for (const registered of [undefined, {}])
  await assert.rejects(
    exported(registered),
    /workero: the OCaml program registered no handler; call Workero\.serve or Workero\.scheduled at module initialisation/,
  );

console.log("ok - index.js exports only the registered handlers");
