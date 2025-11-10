// @ts-nocheck

var obj = { prop: 1 };
with (obj) {
  prop = 2;
}
try {
  prop = 3;
} catch (e) {
  prop = e;
} finally {
  prop = 0;
}
