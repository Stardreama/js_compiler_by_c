const lookup = { a: 1, b: 2 };
const arrayLike = { 0: 'x', 1: 'y', length: 2 };

for (var { key } in { key: 'value' }) {
  console.log(key);
}

for (let [entry] in { entry: 'noop' }) {
  console.log(entry);
}
