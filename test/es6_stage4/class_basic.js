class Point {
  constructor(x, y) {
    this.x = x;
    this.y = y;
  }

  move(dx, dy) {
    this.x += dx;
    this.y += dy;
  }

  get asArray() {
    return [this.x, this.y];
  }

  set asArray([nx, ny]) {
    this.x = nx;
    this.y = ny;
  }

  static origin() {
    return new Point(0, 0);
  }

  static get version() {
    return "1.0";
  }

  static set version(v) {
    Point._version = v;
  }
}

const center = Point.origin();
center.move(10, 5);
Point.version = "2.0";
