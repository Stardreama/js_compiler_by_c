function* counter(start = 0, step = 1) {
  let value = start;
  while (value < start + 5) {
    yield value;
    value += step;
  }
  return value;
}

const tap = function* () {
  yield "a";
  yield* ["b", "c"];
  yield yield* counter(10, 2);
};

const results = [];
for (const value of tap()) {
  results.push(value);
}

const iterable = {
  *[Symbol.iterator]() {
    yield "head";
    yield* counter(1);
  },
};

for (const chunk of iterable) {
  results.push(chunk);
}
