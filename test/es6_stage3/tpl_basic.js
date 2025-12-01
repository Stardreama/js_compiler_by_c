const user = { name: "Ada", score: 41 };

const greeting = `Hello, ${user.name}!`;
const inline = `value`;
const math = `2 + 2 = ${2 + 2}`;
const chained = `a${1}b${2}c${3}`;
const nested = `first ${`inner ${user.score}`}`;

function render(template, value) {
  return `${template}: ${value}`;
}

const lines = `multi\nline`;
const multiLine = `alpha
beta ${user.score}
gamma`;

const result = render(`score`, user.score);
