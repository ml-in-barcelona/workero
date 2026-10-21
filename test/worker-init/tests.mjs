export default {
  async test(_controller, env) {
    await env.WORKER.fetch("http://test/");
  },
};
