class Logger {
  constructor(kind = "base") {
    this.kind = kind;
  }

  log(message) {
    return `[${this.kind}]${message}`;
  }

  get status() {
    return `${this.kind}:ready`;
  }
}

class AdvancedLogger extends Logger {
  constructor(kind) {
    super(kind);
  }

  log(message) {
    return super.log(`ADV:${message}`);
  }

  get status() {
    return `${super.status}/advanced`;
  }
}

class Registry {
  static describe() {
    return "registry";
  }
}

class ChildRegistry extends Registry {
  static describe() {
    return `${super.describe()}:child`;
  }
}

const logger = new AdvancedLogger("system");
logger.log("ping");
logger.status;
ChildRegistry.describe();
