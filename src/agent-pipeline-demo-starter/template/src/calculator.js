export function add(left, right) {
  assertFiniteNumber(left, "left");
  assertFiniteNumber(right, "right");
  return left + right;
}

export function subtract(left, right) {
  assertFiniteNumber(left, "left");
  assertFiniteNumber(right, "right");
  return left - right;
}

function assertFiniteNumber(value, name) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new TypeError(`${name} must be a finite number`);
  }
}
