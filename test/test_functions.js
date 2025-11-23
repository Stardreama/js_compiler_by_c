// Function declarations,调用链与嵌套调用覆盖

function outer(p, q) {
  var sum = p + q;

  function inner(x, y) {
    return x * y;
  }

  var multiplied = inner(sum, p - q);

  return multiplied;
}

function combine(value) {
  return outer(value, value) + outer(value, value + 1);
}

var alias = outer;
var immediate = alias(3, 1);

function dispatcher(seed) {
  var result = 0;

  for (var idx = 0; idx < seed; idx++) {
    result += combine(idx);
  }

  return result + immediate;
}

dispatcher(3);
