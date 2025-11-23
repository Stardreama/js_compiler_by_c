// 对象和数组文字覆盖，强调嵌套访问

var record = {
  id: 42,
  name: "node",
  flags: 0x01 | 0x04,
  nested: {
    coords: [
      [0, 1],
      [2, 3],
    ],
    meta: {
      valid: true,
      count: 2,
    },
  },
};

record.nested.meta.valid = record.flags > 0 ? true : false;

var metrics = [record.nested.coords.length, record.nested.meta.count];

function inspect(meta) {
  return meta.count;
}

inspect(record.nested.meta);
