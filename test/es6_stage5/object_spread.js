const base = {
  a: 1,
  b: 2,
  get sum() {
    return this.a + this.b;
  },
};

const mixin = {
  c: 3,
  ["dynamic-key"]: 4,
  d() {
    return this.c;
  },
};

const merged = {
  label: "merged",
  ...base,
  tail: true,
  ...mixin,
  e: 5,
  ...(() => ({ f: 6, nested: { g: 7 } }))(),
};

const decorated = {
  ...merged,
  ...{
    h: 8,
    i() {
      return this.h;
    },
  },
  ["computed" + "Name"]: 9,
};

const wrapper = {
  wrapper: {
    ...decorated,
    deep: {
      ...merged,
      marker: "ok",
    },
  },
};

const { a, sum, ...rest } = decorated;
const assignDefault = (({ x, ...others }) => ({ x, others }))({
  x: 1,
  y: 2,
  z: 3,
});

void wrapper;
void rest;
void assignDefault;
