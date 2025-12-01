async function* stream(values = []) {
  for (const value of values) {
    yield await Promise.resolve(value);
  }
  return await Promise.resolve(values.length);
}

const asyncTap = async function* (...inputs) {
  for (const entry of inputs) {
    yield await entry;
  }
};

const asyncExpr = async function example(value) {
  return await value;
};

const arrow = async () => await stream([1, 2, 3]);

const container = {
  async method(value) {
    return await asyncExpr(value);
  },
  async *sequence(start = 0) {
    while (start < 3) {
      yield await Promise.resolve(start++);
    }
  },
  async *[Symbol.asyncIterator]() {
    yield* this.sequence(1);
  },
};

class AsyncBox {
  async *values(source) {
    for await (const payload of source) {
      yield payload;
    }
  }

  async increment(value) {
    return 1 + (await value);
  }
}

async function* composed(iterable) {
  yield* container;
  yield* stream(iterable);
}

const box = new AsyncBox();

async function consume(source) {
  for await (const piece of composed(source)) {
    await box.increment(piece);
  }
  return arrow;
}

void consume;
