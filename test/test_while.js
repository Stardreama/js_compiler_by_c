var count = 0;

mainLoop: while (count < 5) {
  if (count === 2) {
    break mainLoop;
  }
  count++;
}

do {
  count--;
  if (count === 1) {
    continue;
  }
} while (count > 0);
