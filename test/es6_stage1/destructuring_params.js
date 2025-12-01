function pick({ x, y = 1 }, [first, ...rest]) {
  return x + y + (rest.length ? first : 0);
}

const arrow = ({ value }) => value;

pick({ x: 1 }, [2, 3, 4]);
arrow({ value: 42 });
