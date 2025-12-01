function collectDefaults(a = 1, b = a + 1, { value } = { value: 3 }) {
  return a + b + value;
}

function mixDestructuring(
  { head, tail: [first, ...rest] } = { head: 0, tail: [] },
  [primary, secondary = primary] = [0, 1],
  ...others
) {
  return { head, primary, rest, others };
}

const expr = function (
  { label = "x", ...other } = {},
  [a = 1, b = 2] = [],
  ...rest
) {
  return { label, other, rest, a, b };
};

function nestedDefaults(options = { factory: (seed = 1) => seed }) {
  return options.factory();
}
