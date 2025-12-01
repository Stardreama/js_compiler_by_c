const double = (x) => x * 2;

const wrapObject = () => ({ value: 42 });

const nested = (value) => ({
  increment: (delta) => value + delta,
});

const inlineInvoke = ((seed = 3) => seed * 2)(5);

const mapper = [1, 2, 3].map((value, index = 0) => value + index);

const pipeline = (input = { total: 0 }) => ({
  total: input.total,
  push: (...items) => items.reduce((sum, item) => sum + item, input.total),
});

const conditional = (flag) => (flag ? () => ({ ok: true }) : (value) => value);
