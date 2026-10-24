(function(root){

 class CompanionVoice {
  constructor(random=Math.random,copy=root.CAT_COPY){this.copy=(root.normalizeCopy||require('./copy-config.js').normalizeCopy)(copy);this.random=random;this.active=false;this.last=-1;this.text='';this.until=0;this.next=Infinity;}
  resume(now){this.active=true;this.text='';this.until=0;this.next=now+this.delay();}
  delay(){const [min,max]=this.copy.intervalSeconds;return (min+this.random()*(max-min))*1000;}
  pause(){this.active=false;this.text='';}
  tick(now){
   if(!this.active)return '';
   if(now>=this.next){const lines=this.copy.study;let index=Math.floor(this.random()*(this.last<0 ? lines.length : Math.max(1,lines.length-1)));if(lines.length>1&&index>=this.last&&this.last>=0)index++;this.last=index;this.text=lines[index];this.until=now+this.copy.displaySeconds*1000;this.next=this.until+this.delay();}
   return now<this.until?this.text:'';
  }
 }
 if(typeof module!=='undefined')module.exports={CompanionVoice};else root.CompanionVoice=CompanionVoice;
})(globalThis);
