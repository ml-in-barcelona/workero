import { connect } from "cloudflare:sockets";
(globalThis.__workero ??= {}).connect = connect;
const registered = globalThis.__workero ?? {};
const handlers = {};
for (const name of ["fetch", "scheduled", "queue", "email"]) {
  if (typeof registered[name] === "function")
    handlers[name] = (...args) => registered[name](...args);
}
if (
  Object.keys(handlers).length +
    Object.keys(registered.durable_objects ?? {}).length +
    Object.keys(registered.entrypoints ?? {}).length +
    Object.keys(registered.workflows ?? {}).length ===
  0
)
  throw new Error(
    "workero: the OCaml program registered no handler; call Workero.serve, Workero.scheduled, Workero.queue or Workero.email at module initialisation",
  );
registered.emailMessage = async (from, to, raw) => {
  const { EmailMessage } = await import("cloudflare:email");
  return new EmailMessage(from, to, raw);
};
export default handlers;
