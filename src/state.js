(function(root){
  class CatState {
    constructor(random = Math.random) {
      this.random = random;
      this.active = true;
      this.reduced = false;
      this.petStart = -Infinity;
      this.petEnd = -Infinity;
      this.nextBlink = 3000 + random() * 4000;
    }
    pet(now) {
      if (!this.active) return;
      if (now >= this.petEnd) this.petStart = now;
      this.petEnd = now + 1900;
      this.nextBlink = this.petEnd + 3000 + this.random() * 4000;
    }
    setActive(active, now) {
      this.active = active;
      this.petStart = this.petEnd = -Infinity;
      this.nextBlink = now + 3000 + this.random() * 4000;
    }
    setReduced(reduced) { this.reduced = reduced; }
    frame(now) {
      if (!this.active) return {petting:false, eyes:0, breath:0, lean:0};
      const petting = now < this.petEnd;
      let eyes = 0, lean = 0;
      const smooth = n => { n = Math.max(0, Math.min(1, n)); return n*n*(3-2*n); };
      if (petting) {
        const envelope = smooth((now-this.petStart)/160) * smooth((this.petEnd-now)/420);
        const eyeRemaining = this.petEnd - 1200 - now;
        eyes = this.reduced ? Number(eyeRemaining > 0) : smooth((now-this.petStart)/65) * smooth(eyeRemaining/110);
        lean = this.reduced ? 0 : envelope;
      } else if (!this.reduced && now >= this.nextBlink) {
        const elapsed = now-this.nextBlink;
        if (elapsed < 55) eyes = smooth(elapsed/55);
        else if (elapsed < 80) eyes = 1;
        else if (elapsed < 190) eyes = 1-smooth((elapsed-80)/110);
        else this.nextBlink = now + 3000 + this.random()*4000;
      }
      return {petting, eyes, lean, breath: this.reduced ? 0 : (1-Math.cos(now/4400*Math.PI*2))/2};
    }
  }
  if (typeof module !== 'undefined') module.exports = {CatState};
  else root.CatState = CatState;
})(globalThis);
