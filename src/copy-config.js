(function(root){
 const defaults={study:['嗯，我还在这里。'],pet:['嗯，再摸一下。'],idle:'你忙你的，我在这里。',paused:'我先歇一会儿。',intervalSeconds:[120,180],displaySeconds:9};
 function normalizeCopy(input={}){
  const lines=(value,fallback)=>Array.isArray(value)&&value.some(s=>typeof s==='string'&&s.trim())?value.filter(s=>typeof s==='string'&&s.trim()).map(s=>s.trim().slice(0,120)):fallback;
  const interval=Array.isArray(input.intervalSeconds)?input.intervalSeconds:defaults.intervalSeconds;
  const min=Number.isFinite(interval[0])?Math.max(30,Math.min(3600,interval[0])):120;
  const max=Number.isFinite(interval[1])?Math.max(min,Math.min(3600,interval[1])):Math.max(min,180);
  return {study:lines(input.study,defaults.study),pet:lines(input.pet,defaults.pet),idle:typeof input.idle==='string'?input.idle.slice(0,120):defaults.idle,paused:typeof input.paused==='string'?input.paused.slice(0,120):defaults.paused,intervalSeconds:[min,max],displaySeconds:Number.isFinite(input.displaySeconds)?Math.max(2,Math.min(30,input.displaySeconds)):9};
 }
 root.normalizeCopy=normalizeCopy;
 if(typeof module!=='undefined')module.exports={normalizeCopy};
})(globalThis);
