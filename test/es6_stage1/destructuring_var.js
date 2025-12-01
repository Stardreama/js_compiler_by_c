const source = { a: 1, b: 2, c: 3 };
const fallback = { coords: { x: 0, y: 0 } };

const { a, b: alias = 2, ...rest } = source;
let [head, tail = 1, ...others] = [10, 20, 30, 40];
const { coords: { x = 4, y = 5 } } = fallback;
var { nested = 'value' } = { nested: 'ok' };
