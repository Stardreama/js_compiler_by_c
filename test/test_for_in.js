// 多形态 for 循环覆盖

var tally = 0;

for (var index = 0; index < 4; index++) {
  tally += index;
}

var value = 3;

for (; value > 0; value--) {
  tally += value;
}

var outer = 0;

for (; outer < 2; outer++) {
  var nested = 2;

  for (; nested >= 0; nested--) {
    tally += outer + nested;
  }
}

for (;;) {
  tally--;
  break;
}
