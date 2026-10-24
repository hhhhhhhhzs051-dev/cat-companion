const {test}=require('node:test');const assert=require('node:assert/strict');
const {normalizeCopy}=require('../src/copy-config.js');const {CompanionVoice}=require('../src/companion.js');
test('replacement text stays literal and single-line lists do not index out of range',()=>{
 const copy=normalizeCopy({study:['<b>自定义台词</b>'],pet:['摸摸'],intervalSeconds:[30,30],displaySeconds:2});const voice=new CompanionVoice(()=>.9,copy);voice.resume(0);assert.equal(voice.tick(30000),'<b>自定义台词</b>');assert.equal(voice.tick(62000),'<b>自定义台词</b>');
});
test('bad content and unsafe timer values fall back or clamp',()=>{
 const copy=normalizeCopy({study:[],pet:[null,' '],intervalSeconds:[-1,-20],displaySeconds:Infinity});assert.ok(copy.study.length);assert.ok(copy.pet.length);assert.deepEqual(copy.intervalSeconds,[30,30]);assert.equal(copy.displaySeconds,9);
});
