try {
  throw { message: "failed", info: { code: 500 } };
} catch ({ message, info: { code = 0 } }) {
  console.log(message, code);
}

try {
  throw { payload: { reason: "timeout", meta: { retry: true } } };
} catch ({ payload: { reason = "error", meta: { retry = false } = {} } = {} }) {
  console.log(reason, retry);
}
