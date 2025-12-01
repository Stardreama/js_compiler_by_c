// Rest parameters must appear at the end of the parameter list.
const invalid = (...rest, last) => rest;

const alsoInvalid = (first, ...others, final = 0) => first;
