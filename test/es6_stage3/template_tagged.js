function tag(strings, ...values) {
  return { strings, values };
}

const value = 10;
const info = tag`value:${value}`;
const more = tag`sum=${1 + 2} tail`;

const obj = {
  format(x) {
    return x;
  },
  fn() {
    return tag;
  },
};

function getTag() {
  return tag;
}

const memberTagged = obj.format`ok ${value}`;
const callTagged = obj.fn()`data ${value}`;
const inlineTagged = (function () {
  return tag;
})()`inner ${value}`;
const factoryTagged = getTag()`late ${value}`;
