// @ts-nocheck

var message = "fail";
var obj = { prop: 1 };

with (obj) {
  prop = 2;
}

try {
  if (prop > 1) {
    throw message;
  }
} catch (error) {
  message = error;
} finally {
  prop = 0;
}
