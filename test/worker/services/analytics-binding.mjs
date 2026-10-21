const points = [];

export default () => ({
  writeDataPoint(point) {
    points.push({
      keys: Object.keys(point),
      indexes: point.indexes,
      doubles: point.doubles,
      blobs: (point.blobs ?? []).map((b) =>
        typeof b === "string" ? b : { buffer: b instanceof ArrayBuffer, bytes: [...new Uint8Array(b)] },
      ),
    });
  },
  async points() {
    return points;
  },
});
