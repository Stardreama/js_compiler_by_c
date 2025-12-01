function ident(strings, ...values) {
  return { strings, values };
}

const value = 3;

const separatedTag = ident`line:${value}`;

const chainedTemplates = ident`alpha ${value}``beta ${value + 1}`;

const multilineExpr = `prefix ${ident`inner ${value}`.strings[0]} suffix`;

function wrap() {
  return ident`wrapped ${value}`;
}

const block = {
  [`field-${value}`]: `value ${value + 1} done`,
};

const ensure = [separatedTag, chainedTemplates, wrap(), block, multilineExpr];
