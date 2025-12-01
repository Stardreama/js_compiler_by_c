const prefix = "id";
const suffix = 7;

const store = {};
store[`${prefix}:value`] = `value-${suffix}`;

const methods = {};
methods[`method-${prefix}`] = (label = `label-${prefix}`) => `${label}:${suffix}`;

const nested = { box: {} };
nested.box[`inner-${suffix}`] = `inside ${suffix}`;

const arrayOfTemplates = [
  `${prefix}-${0}`,
  `${prefix}-${suffix}`,
  `${prefix}-${suffix + 1}`,
];

function headline(text = `headline-${suffix}`) {
  return `${text}!`;
}

const methodResult = methods[`method-${prefix}`]();
const headlineResult = headline();
const destructured = (({ value } = { value: `${prefix}:value` }) => value)();
const propertyAccess = nested.box[`inner-${suffix}`];
const combined = `${methodResult} ${headlineResult} ${destructured} ${propertyAccess}`;
