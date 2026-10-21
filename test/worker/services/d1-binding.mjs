class Statement {
  constructor(service, sql, params = []) {
    this.service = service;
    this.sql = sql;
    this.params = params;
  }
  bind(...params) {
    return new Statement(this.service, this.sql, params);
  }
  async raw(options) {
    const { columnNames, rows } = await this.service.execute(this.sql, this.params);
    return options?.columnNames ? [columnNames, ...rows] : rows;
  }
  async run() {
    return await this.service.execute(this.sql, this.params);
  }
}

export default ({ DATABASE }) => ({
  prepare: (sql) => {
    if (sql.trim() === "") throw new TypeError("D1_ERROR: no SQL statement");
    return new Statement(DATABASE, sql);
  },
});
