import { DurableObject, WorkerEntrypoint } from "cloudflare:workers";

const plain = (value) =>
  value instanceof ArrayBuffer ? Array.from(new Uint8Array(value)) : value;

const bindable = (value) => {
  if (value instanceof Uint8Array) return value.slice().buffer;
  if (Array.isArray(value)) return new Uint8Array(value).buffer;
  return value;
};

export class Database extends DurableObject {
  execute(sql, params) {
    const { sql: db } = this.ctx.storage;
    const cursor = db.exec(sql, ...params.map(bindable));
    const columnNames = cursor.columnNames;
    const rows = [...cursor.raw()].map((row) => row.map(plain));
    const changes = db.exec("SELECT changes() AS changes").one().changes;
    return { success: true, columnNames, rows, meta: { changes } };
  }
}

export class D1 extends WorkerEntrypoint {
  async execute(sql, params) {
    const { DATABASE } = this.env;
    return await DATABASE.get(DATABASE.idFromName("test")).execute(sql, params);
  }
}
