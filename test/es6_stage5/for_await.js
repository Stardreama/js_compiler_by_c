async function* makeAsyncRange(limit = 3) {
  let index = 0;
  while (index < limit) {
    yield await Promise.resolve(index++);
  }
}

const asyncIterable = {
  async *[Symbol.asyncIterator]() {
    yield* makeAsyncRange(2);
    return 42;
  },
};

async function consume(iterable) {
  const seen = [];
  for await (const value of iterable) {
    seen.push(await Promise.resolve(value));
  }

  for await (let [idx, val] of (async function* () {
    let counter = 0;
    while (counter < 2) {
      const resolved = val !== undefined ? val : counter;
      yield [counter, await Promise.resolve(resolved)];
      counter += 1;
    }
  })()) {
    if (idx > 10) break;
    seen.push(val);
  }

  for await (const { value } of (async function* () {
    yield { value: 1 };
  })()) {
    if (!value) break;
  }

  for await (var chunk of makeAsyncRange()) {
    if (chunk < 0) {
      continue;
    }
  }

  return seen;
}

async function monitor() {
  for await (const entry of asyncIterable) {
    if (entry === undefined) {
      break;
    }
  }
}

void consume;
void monitor;
