const assert = require("node:assert/strict");

function matches(actual, [op, bound]) {
  if (op === "in") return bound.includes(actual);
  const key = (v) => {
    if (Number.isInteger(v?.seconds)) return BigInt(v.seconds) * 1_000_000_000n + BigInt(v.nanoseconds);
    if (v?.toDate) v = v.toDate();
    return v instanceof Date ? BigInt(v.getTime()) * 1_000_000n : v;
  };
  const a = key(actual), b = key(bound);
  if (typeof a !== typeof b) return false;
  if (op === "==") return a === b;
  if (op === "<") return a < b;
  assert.equal(op, ">=");
  return a >= b;
}

// Each attempt reads its own snapshot. Changes to documents actually read
// (including a missing document) retry the callback. Writes commit together.
class MemoryDB {
  constructor(rows) {
    this.rows = new Map(Object.entries(rows));
    this.next = this.writes = this.retries = 0;
  }
  collection(name) {
    const query = (filters) => ({
      name, filters,
      doc: (id = `new-${++this.next}`) => ({ id, path: `${name}/${id}` }),
      where: (field, ...condition) => query([...filters, [field, condition]]),
    });
    return query([]);
  }
  async runTransaction(work) {
    for (let attempt = 0; attempt < 5; attempt++) {
      const snapshot = new Map(this.rows), reads = new Set(), writes = [];
      const read = (ref) => {
        reads.add(ref.path);
        return { ref, id: ref.id, exists: snapshot.has(ref.path), data: () => snapshot.get(ref.path) };
      };
      const result = await work({
        get: async (ref) => {
          assert.equal(writes.length, 0, "all Firestore reads must precede writes");
          if (ref.path) return read(ref);
          const docs = [];
          for (const [path, row] of snapshot) {
            const [name, id] = path.split("/");
            if (name === ref.name && ref.filters.every(([k, c]) => matches(row[k], c))) {
              docs.push(read({ path, id }));
            }
          }
          return { docs };
        },
        update: (ref, data) => writes.push(["update", ref.path, data]),
        create: (ref, data) => writes.push(["create", ref.path, data]),
      });
      if (this.beforeCommit) {
        const hook = this.beforeCommit;
        this.beforeCommit = null;
        await hook();
      }
      if ([...reads].some((p) => this.rows.get(p) !== snapshot.get(p))) {
        this.retries++;
        continue;
      }
      for (const [op, path, data] of writes) {
        assert.equal(this.rows.has(path), op === "update", `${op} precondition`);
        assert.ok(!Object.values(data).includes(undefined), "Firestore rejects undefined");
      }
      for (const [, path, data] of writes) this.rows.set(path, { ...this.rows.get(path), ...data });
      this.writes += writes.length;
      return result;
    }
    throw new Error("Unresolved transaction contention");
  }
}

module.exports = { MemoryDB };
