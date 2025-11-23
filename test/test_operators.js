// Operator coverage smoke test for extended grammar

let a = 5,
  b = 3,
  c = 0;
let obj = { value: 10 };
let arr = [1, 2, 3];

c = a ? b : c;
const nested = a > b ? (b < c ? a : b) : c;

c += a;
c -= b;
c *= 2;
c /= arr.length;
c %= 4;
c &= 0xff;
c |= 0x10;
c ^= 0x04;
c <<= 2;
c >>= 1;
c >>>= 1;

const bits = (a & b) | (a ^ b ^ (a << 2));
const shifts = ((a << 1) >>> 1) >> 1;

const type = typeof c;
const removed = delete obj.value;
const voided = void (c + b);

const seq = (a++, b--, a + b, (c = a & b));
const mix = (a | b && c ^ b) || a & (b << 1);

let chained = 1;
chained = (chained += 2) ? (chained &= 1) : (chained ^= 4);

const triple = (a, b, c, seq);

void type; // ensure unary void in bare statement
removed;
voided;
triple;
