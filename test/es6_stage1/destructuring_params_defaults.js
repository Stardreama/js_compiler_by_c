function configure(
  { timeout = 1000, options: { verbose = false, retries = 0 } = {} } = {},
  [first = null, ...rest] = []
) {
  return timeout + retries + (rest.length ? rest[0] : 0);
}

const consume = function ([head = 0, middle = 0, tail = 0] = []) {
  return head + middle + tail;
};

const useArrow = ({ value = 0 } = { value: 1 }, [{ flag = true } = {}] = []) =>
  value && flag;

function restOnly([...items] = []) {
  return items.length;
}

configure({ timeout: 2000, options: { verbose: true, retries: 3 } }, [1, 2, 3]);
consume([4, 5, 6]);
useArrow({ value: 5 }, [{ flag: false }]);
restOnly([1, 2]);
