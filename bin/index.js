export default {
  fetch: (request, env, ctx) => globalThis.__workero.fetch(request, env, ctx),
};
