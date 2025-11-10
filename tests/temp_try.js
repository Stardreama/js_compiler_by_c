try {
  throw value;
} catch (err) {
  value = err;
} finally {
  value = 0;
}
