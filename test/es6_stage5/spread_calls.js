function combine(a, b, ...rest) {
  return [a, b, rest.length];
}

const args1 = [1, 2, 3];
const first = combine(...args1);

function wrap(fn, ...values) {
  return fn(...values);
}

function tag(label, ...items) {
  return `${label}:${items.join(",")}`;
}

const joined = wrap(tag, "id", ...["a", "b"], ..."cd");

const matrix = [
  [10, 20],
  [30, 40],
];

const flat = [...matrix[0], ...matrix[1], ...(() => [50])()];

const runner = (...values) => values.length;
const count = runner(...flat);
