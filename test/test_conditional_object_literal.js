function choose(flag) {
  return flag ? { value: 1 } : { value: 2 };
}

const nextOrDone = condition => (condition ? { next: () => ({ done: false }) } : { next: () => ({ done: true }) });

for (var iter = nextOrDone(true); !iter.done; iter = nextOrDone(false)) {
  iter.next();
}
