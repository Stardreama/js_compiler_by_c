const matrix = [
  [1, 2],
  [3, 4],
];

const flattened = [];
for (const row of matrix) {
  for (const value of row) {
    flattened.push(value);
  }
}

const entries = new Map([
  ["alpha", 1],
  ["beta", 2],
]);

for (const [key, value] of entries) {
  flattened.push(key.length + value);
}

let symbol;
for (symbol of "xy") {
  flattened.push(symbol);
}
