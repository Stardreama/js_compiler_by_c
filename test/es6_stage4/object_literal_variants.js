const base = "key";

const component = {
  base,
  [base + "Suffix"]: 1,
  method(value = 1) {
    return value + this[base + "Suffix"];
  },
  *iterator() {
    yield this.base;
    yield this[base + "Suffix"];
  },
  get summary() {
    return `${this.base}:${this[base + "Suffix"]}`;
  },
  set summary(text) {
    const parts = text.split(":");
    this.base = parts[0];
    this[base + "Suffix"] = parts[1];
  },
};

for (const entry of component.iterator()) {
  entry;
}
component.method();
component.summary = "updated:2";
component.summary;
