const add = (a, b = 1) => a + b;

const pickRest = ({ value = 0, ...rest }) => ({ value, rest });

const tail = (...items) => items;

const wrap = () => {
  return 42;
};

const nested = (x) => (y) => x + y;

const arrayDefault = ([head = 0, ...tail] = [1, 2, 3]) => head + tail.length;

const empty = () => ({ ok: true });
