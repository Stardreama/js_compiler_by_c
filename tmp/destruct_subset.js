let payload = { foo: "name", bar: 3, rest: [1, 2, 3] };
let target = { name: "" };
let items = { first: 0, second: 0 };

({ foo: target.name, bar = 2 } = payload);
[items.first, items.second = 10] = [5, undefined];
let first = 0;
let remaining = [];
