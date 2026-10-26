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
  terminate(options) {
    return this.engine.terminate(this.id, options);
  }
  restart(options) {
    return this.engine.restart(this.id, options);
  }
  delete() {
    return this.engine.delete(this.id);
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
  async deleteBatch(ids) {
    return ENGINE.deleteBatch(ids);
  },
  async get(id) {
    return new Instance((await ENGINE.get(id)).id, ENGINE);
  },
});
