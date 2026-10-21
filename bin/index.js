const registered = globalThis.__workero ?? {};
const handlers = {};
for (const name of ["fetch", "scheduled"]) {
  if (typeof registered[name] === "function")
    handlers[name] = (...args) => registered[name](...args);
}
if (Object.keys(handlers).length + Object.keys(registered.durable_objects ?? {}).length === 0)
  throw new Error(
    "workero: the OCaml program registered no handler; call Workero.serve or Workero.scheduled at module initialisation",
  );
export default handlers;
