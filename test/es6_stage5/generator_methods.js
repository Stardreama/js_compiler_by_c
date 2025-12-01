const tracker = {
  *range(start, end, step = 1) {
    let current = start;
    while (current <= end) {
      yield current;
      current += step;
    }
  },
  *mix(values) {
    yield "begin";
    try {
      yield* values;
    } finally {
      yield "cleanup";
    }
  },
};

class Pool {
  constructor(items) {
    this.items = items;
  }

  *[Symbol.iterator]() {
    yield* this.items;
  }

  static *sequence(start) {
    yield start;
    yield* tracker.range(start + 1, start + 2);
  }
}

const pool = new Pool(["x", "y"]);
const collected = [];
for (const piece of tracker.mix(pool)) {
  collected.push(piece);
}
for (const chunk of Pool.sequence(5)) {
  collected.push(chunk);
}
