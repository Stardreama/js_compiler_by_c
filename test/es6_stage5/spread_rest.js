const base = [1, 2];
const extended = [...base, 3, ...[4, 5]];

function join(head, ...rest) {
  return [head, rest.length];
}

const merged = join("first", ...extended);

function collectAll(...items) {
  return [...items, items.length];
}

const combined = collectAll(...extended, ...[6, 7]);

const nested = [...base, merged, ...(() => [99])()];

function forward(a, b, c, ...extra) {
  return [a, b, c, extra.length];
}

const args = [10, 20, 30];
const forwarded = forward(...args, ...[40]);
