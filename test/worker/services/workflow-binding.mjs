class Instance {
  constructor(id, engine) {
    this.id = id;
    this.engine = engine;
  }
  status() {
    return this.engine.status(this.id);
  }
  pause() {
    return this.engine.pause(this.id);
  }
  resume() {
    return this.engine.resume(this.id);
  }
  terminate() {
    return this.engine.terminate(this.id);
  }
  restart() {
    return this.engine.restart(this.id);
  }
  sendEvent({ type, payload }) {
    return this.engine.sendEvent(this.id, { type, payload });
  }
}

export default ({ ENGINE }) => ({
  async create(options) {
    return new Instance((await ENGINE.create(options)).id, ENGINE);
  },
  async createBatch(options) {
    const result = await ENGINE.createBatch(options);
    return { created: result.created.map(({ id }) => new Instance(id, ENGINE)), errors: result.errors };
  },
  async get(id) {
    return new Instance((await ENGINE.get(id)).id, ENGINE);
  },
});
