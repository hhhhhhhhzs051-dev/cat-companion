const {test}=require('node:test');
const assert=require('node:assert/strict');
const {CompanionVoice}=require('../src/companion.js');
test('quiet interval, brief text and no immediate repeats',()=>{
 const v=new CompanionVoice(()=>0,require('../src/cat-copy.json')); v.resume(0);
 assert.equal(v.tick(119999),''); const first=v.tick(120000); assert.ok(first);
 assert.equal(v.tick(129000),''); assert.notEqual(v.tick(249000),first);
});
test('pause hides text and resume does not catch up',()=>{
 const v=new CompanionVoice(()=>0,require('../src/cat-copy.json'));v.resume(0);v.tick(120000);v.pause();
 assert.equal(v.tick(900000),'');v.resume(900000);assert.equal(v.tick(900001),'');
});

test('first phrase can reach every item including last',()=>{
 const seen=new Set();for(const n of [.01,.5,.99]){const v=new CompanionVoice(()=>n,{study:['A','B','C']});v.resume(0);seen.add(v.tick(1e9));}assert.deepEqual([...seen],['A','B','C']);
});
