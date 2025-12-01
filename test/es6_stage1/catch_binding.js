try {
  throw { message: "failed", info: { code: 500 } };
} catch ({ message, info: { code = 0 } }) {
  console.log(message, code);
}
