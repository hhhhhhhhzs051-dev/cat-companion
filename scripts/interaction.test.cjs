const {test} = require('node:test');
const assert = require('node:assert/strict');
const {CatState} = require('../src/state.js');

test('petting responds immediately and repeated strokes extend one response without a queue', () => {
  const cat = new CatState(() => 0.5);
  cat.pet(100);
  assert.equal(cat.frame(100).petting, true);
  assert.ok(cat.frame(300).eyes > 0.9);
  for (let t=350;t<=850;t+=50) cat.pet(t);
  assert.equal(cat.frame(1600).petting, true);
  assert.equal(cat.frame(3500).petting, false);
  assert.equal(cat.frame(3500).eyes, 0);
});
test('natural blink closes and reopens, then waits before another blink', () => {
  const cat = new CatState(() => 0);
  assert.equal(cat.frame(0).eyes, 0);
  assert.ok(cat.frame(3100).eyes > 0.9);
  assert.equal(cat.frame(3500).eyes, 0);
  assert.equal(cat.frame(5000).eyes, 0);
});
test('hidden page does not accumulate petting or rapid catch-up blinks', () => {
  const cat = new CatState(() => 0);
  cat.pet(100);
  cat.setActive(false, 200);
  assert.equal(cat.frame(10000).petting, false);
  assert.equal(cat.frame(10000).eyes, 0);
  cat.setActive(true, 10000);
  assert.equal(cat.frame(10001).eyes, 0);
});
test('reduced motion disables automatic motion but preserves static pet feedback', () => {
  const cat = new CatState(() => 0);
  cat.setReduced(true);
  assert.equal(cat.frame(3100).eyes, 0);
  assert.equal(cat.frame(3100).breath, 0);
  cat.pet(4000);
  assert.equal(cat.frame(4000).petting, true);
  assert.equal(cat.frame(4000).eyes, 1);
  assert.equal(cat.frame(4000).lean, 0);
});
test('a quick blink has fully reopened by 190ms', () => {
  const cat = new CatState(() => 0);
  assert.equal(cat.frame(3070).eyes, 1);
  assert.equal(cat.frame(3190).eyes, 0);
});
test('pet eyes reopen within 700ms while the body settles gently', () => {
  const cat = new CatState(() => .5);
  cat.pet(100);
  assert.equal(cat.frame(800).eyes, 0);
  assert.equal(cat.frame(800).petting, true);
  cat.setReduced(true);
  assert.equal(cat.frame(800).eyes, 0);
});
