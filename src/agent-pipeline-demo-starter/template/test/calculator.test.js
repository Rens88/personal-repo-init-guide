import assert from "node:assert/strict";
import test from "node:test";

import { add, subtract } from "../src/calculator.js";

test("add returns the sum of two finite numbers", () => {
  assert.equal(add(2, 3), 5);
});

test("subtract returns the difference of two finite numbers", () => {
  assert.equal(subtract(8, 3), 5);
});

test("operations reject non-finite operands", () => {
  assert.throws(() => add(Number.POSITIVE_INFINITY, 1), TypeError);
  assert.throws(() => subtract(1, Number.NaN), TypeError);
});
