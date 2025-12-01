class Animal {
  constructor(kind) {
    this.kind = kind;
  }

  speak(sound) {
    return `${this.kind}:${sound}`;
  }
}

class Dog extends Animal {
  constructor(name) {
    super("dog");
    this.name = name;
  }

  speak() {
    return super.speak(`${this.name} barks`);
  }

  static create(name) {
    return new Dog(name);
  }
}

const buddy = Dog.create("Buddy");
buddy.speak();
