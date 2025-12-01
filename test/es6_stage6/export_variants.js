const base = 10;
let counter = 0;

export { base as baseline };
export let ticking = true,
  speed = 2;
export const limits = { min: 0, max: 100 };
export function increment(value) {
  counter += value;
  return counter;
}

export class Reporter {
  constructor(label) {
    this.label = label;
  }
  log(...args) {
    console.log(this.label, ...args);
  }
}

export default class DefaultReporter extends Reporter {}
