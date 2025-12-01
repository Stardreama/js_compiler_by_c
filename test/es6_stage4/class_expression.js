const Base = class {
  constructor(label) {
    this.label = label;
  }

  describe() {
    return this.label;
  }

  static make(label) {
    return new this(label);
  }
};

const Derived = class extends Base {
  constructor(label, extra) {
    super(label);
    this.extra = extra;
  }

  ["combine" + "Value"]() {
    return `${this.label}:${this.extra}`;
  }

  static ["create" + "Instance"](label) {
    return new Derived(label, label.length);
  }
};

const instance = Derived["createInstance"]("core");
instance["combineValue"]();
