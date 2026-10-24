(() => {
  const stage = document.getElementById('stage');
  const petButton = document.getElementById('pet');
  const pauseButton = document.getElementById('pause');
  const response = document.getElementById('response');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const state = new CatState();
  state.setReduced(reduced.matches);
  stage.insertAdjacentHTML('beforeend', CatArt.scene());
  const cat = document.getElementById('breathing-cat');
  const eyes = document.getElementById('eyelid-reveal');
  const hit = document.getElementById('head-hit');
  let ready = false, paused = false, raf = 0, reducedTimer = 0;
  let stroke = null, lastText = null, forcedEyes = false;
  const now = () => performance.now();
  const copy = normalizeCopy(window.CAT_COPY);
  const voice = new CompanionVoice(Math.random, copy);
  let study = new URLSearchParams(location.search).get('mode') === 'study';
  let voiceTimer = 0;
  let desktopVisible = true;
  let petLine = copy.pet[0];
  const petLines = copy.pet;
  let lastPetLine = 0;
  function syncVoice() {
    clearInterval(voiceTimer);
    voiceTimer=0;
    if (study && ready && desktopVisible && !paused && !document.hidden && document.getElementById('voice-enabled').checked) {
      voice.resume(now());
      voiceTimer = setInterval(() => render(now()), 1000);
    } else voice.pause();
  }
  function setMode(value) {
    study = value;
    document.body.classList.toggle('study',study);
    document.getElementById('mode-pet').setAttribute('aria-pressed',String(!study));
    document.getElementById('mode-study').setAttribute('aria-pressed',String(study));
    document.querySelector('.study-tools').hidden = !study;
    syncVoice();
    render(now());
  }
  document.getElementById('mode-pet').addEventListener('click',()=>setMode(false));
  document.getElementById('mode-study').addEventListener('click',()=>setMode(true));
  document.getElementById('voice-enabled').addEventListener('change',()=>{syncVoice();render(now());});
  document.getElementById('open-window').addEventListener('click',()=>{
    const url = new URL(location.href); url.searchParams.set('mode','study'); url.searchParams.delete('layers');
    let child;
    try { child = window.open(url.href, 'cat-study', 'popup=yes,width=380,height=610'); } catch (_) {}
    document.getElementById('window-note').textContent = child ? '小窝打开了，可以把它摆到学习窗口旁边。' : '浏览器没有打开新窗口；也可以直接缩小当前窗口。';
    if(child){ if(!paused) pauseButton.click(); child.focus(); }
  });
  function render(time) {
    const f = state.frame(time);
    const lift = f.breath * 2.0 + f.lean * 2.5;
    const sy = 1 + f.breath * .006;
    cat.style.transform = `translate3d(0, ${-lift}px, 0) rotate(${-f.lean*.32}deg) scaleY(${sy})`;
    eyes.setAttribute('height', String((forcedEyes ? 1 : f.eyes) * 120));
    stage.dataset.state = paused ? 'paused' : f.petting ? 'petting' : 'idle';
    const whisper = voice.tick(time);
    const text = paused ? copy.paused : f.petting ? petLine : study ? whisper || (window.CAT_DESKTOP ? '' : copy.idle) : '它在这里，慢慢呼吸。';
    if (text !== lastText) { response.textContent = text; lastText = text; }
  }
  function loop(t) { render(t); raf = requestAnimationFrame(loop); }
  function sync() {
    cancelAnimationFrame(raf);
    clearTimeout(reducedTimer);
    raf = 0;
    const active = ready && desktopVisible && !paused && !document.hidden;
    state.setActive(active, now());
    petButton.disabled = !ready || paused;
    hit.setAttribute('aria-disabled', String(!active));
    hit.setAttribute('tabindex', active ? '0' : '-1');
    syncVoice();
    render(now());
    if (active && !reduced.matches) raf = requestAnimationFrame(loop);
  }
  function pet() {
    if (!ready || !desktopVisible || paused || document.hidden) return;
    if (!state.frame(now()).petting) {
      lastPetLine = (lastPetLine + 1 + Math.floor(Math.random()*(petLines.length-1))) % petLines.length;
      petLine = petLines[lastPetLine];
    }
    state.pet(now());
    render(now()); // Immediate textual feedback, before the animation advances.
    if (reduced.matches) {
      clearTimeout(reducedTimer);
      reducedTimer = setTimeout(() => {
        render(now());
        reducedTimer = setTimeout(() => render(now()), 1200);
      }, 750);
    }
  }
  petButton.addEventListener('click', pet);
  hit.addEventListener('keydown', e => {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); if (!e.repeat) pet(); }
  });
  hit.addEventListener('pointerdown', e => {
    if (!e.isPrimary || e.button !== 0 || paused || !ready) return;
    e.preventDefault();
    hit.setPointerCapture(e.pointerId);
    stroke = {id:e.pointerId, x:e.clientX, y:e.clientY, time:now()};
    pet();
  });
  hit.addEventListener('pointermove', e => {
    if (!stroke || e.pointerId !== stroke.id) return;
    const distance = Math.hypot(e.clientX-stroke.x, e.clientY-stroke.y);
    if (distance > 10 && now()-stroke.time > 110) {
      const box = hit.getBoundingClientRect();
      if (e.clientX < box.left || e.clientX > box.right || e.clientY < box.top || e.clientY > box.bottom) return;
      pet(); stroke = {id:e.pointerId, x:e.clientX, y:e.clientY, time:now()};
    }
  });
  const release = () => { stroke = null; };
  ['pointerup','pointercancel','lostpointercapture'].forEach(type => hit.addEventListener(type, release));
  function togglePause() {
    paused = !paused;
    pauseButton.setAttribute('aria-pressed', String(paused));
    document.getElementById('pause-label').textContent = paused ? '继续陪伴' : '休息一下';
    document.getElementById('pause-icon').textContent = paused ? '▷' : 'Ⅱ';
    release(); sync();
  }
  pauseButton.addEventListener('click',togglePause);
  document.addEventListener('visibilitychange', () => { release(); sync(); });
  reduced.addEventListener('change', () => { state.setReduced(reduced.matches); sync(); });
  window.addEventListener('pagehide', () => { cancelAnimationFrame(raf); clearTimeout(reducedTimer); clearInterval(voiceTimer); voice.pause(); });
  window.addEventListener('pageshow', () => { if (ready) sync(); });
  document.getElementById('retry').addEventListener('click', () => location.reload());
  window.catDesktop = {
    pet,
    setVisible: (value) => { desktopVisible=Boolean(value); release(); sync(); },
    pause: togglePause,
    voice: () => { const input=document.getElementById('voice-enabled'); input.checked=!input.checked; syncVoice();render(now());return input.checked; },
    inspect: () => ({ready,paused,desktopVisible,animating:raf!==0,speakingTimer:voiceTimer!==0,voice:document.getElementById('voice-enabled').checked,copy,eye:Number(eyes.getAttribute('height'))})
  };
  if(window.CAT_DESKTOP){
    study=true;document.body.classList.add('desktop-pet');
    const svg=document.getElementById('cat-scene');
    const defs=svg.querySelector('defs');
    defs.insertAdjacentHTML('beforeend', '<clipPath id="complete-bed-silhouette"><path d="M42 375 C42 82 1488 82 1488 375 L1488 726 C1488 1004 42 1004 42 726 Z"/></clipPath><clipPath id="complete-bed-front"><path d="M-98 625 C-98 872 1348 872 1348 625 L1348 1274 L-98 1274 Z"/></clipPath>');
    const bed='<g transform="translate(-140 250)" clip-path="url(#complete-bed-silhouette)"><image href="assets/bed-complete-v2.png" width="1536" height="1024"/></g>';
    svg.querySelector('[data-layer="background"]').innerHTML=bed;
    svg.querySelector('[data-layer="foreground"]').innerHTML='<g clip-path="url(#complete-bed-front)">'+bed+'</g>';
    svg.setAttribute('viewBox','-135 165 1525 1085');
  }
  setMode(study);
  const images = [...stage.querySelectorAll('image')].map(node => node.getAttribute('href'));
  Promise.all([...new Set(images)].map(src => new Promise((resolve, reject) => {
    const image = new Image(); image.onload = resolve; image.onerror = reject; image.src = src;
  }))).then(() => {
    ready = true; stage.classList.add('ready'); stage.setAttribute('aria-busy', 'false');
    document.getElementById('loading').hidden = true; pauseButton.disabled = false; sync();
    window.webkit?.messageHandlers?.catHealth?.postMessage('ready');
  }).catch(() => {
    window.webkit?.messageHandlers?.catHealth?.postMessage('failed');
    document.getElementById('loading').textContent = '小猫的图片还没加载好。';
    response.textContent = '请重新打开试试。'; document.getElementById('retry').hidden = false;
    stage.setAttribute('aria-busy','false');
  });
  if (new URLSearchParams(location.search).has('layers') || document.body.dataset.inspect === 'true') {
    document.body.classList.add('inspect');
    const panel = document.getElementById('layer-panel'); panel.hidden = false;
    panel.innerHTML = '<h2>D 版 · 素材分层检查</h2><p>关闭底图可查看透明区域。猫身为原画蒙版层；双眼为生成素材的局部柔边层。耳朵随猫身保留，本版没有独立耳部或四肢骨骼。</p>';
    const labels = {background:'空猫窝／背景',cat:'猫身原画',leftEye:'左眼闭合',rightEye:'右眼闭合',foreground:'前景猫窝'};
    Object.entries(labels).forEach(([key,label]) => {
      const el = document.createElement('label');
      const input = document.createElement('input'); input.type='checkbox'; input.checked=true;
      input.addEventListener('change', () => { stage.querySelector(`[data-layer="${key}"]`).style.display = input.checked ? '' : 'none'; });
      el.append(input, document.createTextNode(label)); panel.append(el);
    });
    const el = document.createElement('label'), input = document.createElement('input'); input.type='checkbox';
    input.addEventListener('change', () => { forcedEyes=input.checked; render(now()); });
    el.append(input, document.createTextNode('保持闭眼，检查眼部接缝')); panel.append(el);
  }
})();
