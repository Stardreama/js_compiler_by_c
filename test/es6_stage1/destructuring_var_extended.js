const config = {
  server: { host: "localhost", port: 8080 },
  flags: { secure: true },
  values: [1, 2, 3, 4],
  meta: { version: "1.0.0" },
};

let {
  server: { host = "127.0.0.1", port = 80 } = {},
  flags: { secure = false, mode = "dev" } = {},
} = config;

const [first = 0, second = 1, third = 2, ...restValues] = config.values;

var [{ version = "0.0.0" } = {}] = [config.meta];

const [...cloned] = config.values;

let { values: [head = 0, ...tail] = [], missing: fallback = "none" } = config;

const {
  server: { host: renamedHost, credentials: { user = "root" } = {} } = {},
} = config;
