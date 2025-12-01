const objects = {
  entry1: { key: "a", value: 1 },
  entry2: { key: "b" },
};

const tuples = {
  pair1: ["x", 1],
  pair2: ["y"],
};

for (const { key, value = 0 } in objects) {
  console.log(key, value);
}

for (let [name, count = 0, ...rest] in tuples) {
  console.log(name, count, rest.length);
}
