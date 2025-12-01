const descriptor = {
  name: "Widget",
  ["category" + "Name"]: "ui",
  get info() {
    return `${this.name}:${this.categoryName}`;
  },
  set info(value) {
    [this.name, this.categoryName] = value.split(":");
  },
  build() {
    return `${this.name}-${this.categoryName}`;
  },
};

descriptor.info = "Panel:layout";
descriptor.build();
