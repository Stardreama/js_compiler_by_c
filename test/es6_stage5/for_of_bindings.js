const records = [
  { coords: [1, 2], meta: { label: "alpha" } },
  { coords: [3], meta: { label: "beta" } },
];

const totals = [];
for (const {
  coords: [x, y = 0],
  meta: { label },
} of records) {
  totals.push(x + y + label.length);
}

for (let [first, ...rest] of [[10, 20, 30], [5]]) {
  totals.push(first + rest.length);
}

const nested = new Set([
  ["p", 1],
  ["q", 2],
]);
for (const [key, value] of nested) {
  totals.push(key.length * value);
}
