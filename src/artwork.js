(function(root) {
  const W = 1254;
  // Coordinates stay in the accepted D artwork's 1254 x 1254 space.
  // Raster originals are retained intact; SVG masks form editable runtime layers.
  const catOutline = 'M 87 744 C 103 669 120 575 156 492 C 190 407 256 364 334 338 C 389 321 438 316 486 319 L 479 217 C 498 206 549 247 598 270 L 634 264 654 274 675 267 697 279 727 274 751 288 777 280 805 287 C 864 278 971 231 1039 190 C 1043 233 1017 305 1005 354 C 1052 444 1080 535 1096 647 C 1100 696 1094 749 1079 784 C 811 836 363 824 87 744 Z';
  const frontOutline = 'M 0 700 C 225 831 934 864 1254 697 L 1254 1254 L 0 1254 Z';
  const definitions = `
    <clipPath id="eyelid-wipe"><rect id="eyelid-reveal" x="590" y="493" width="365" height="0"/></clipPath>
    <clipPath id="cat-clip"><path d="${catOutline}"/></clipPath>
    <clipPath id="front-clip"><path d="${frontOutline}"/></clipPath>
    <filter id="soft-eye" x="-20%" y="-25%" width="140%" height="150%"><feGaussianBlur stdDeviation="4"/></filter>
    <mask id="left-eye-mask" maskUnits="userSpaceOnUse" x="595" y="498" width="178" height="109"><ellipse cx="685" cy="551" rx="75" ry="34" fill="white" filter="url(#soft-eye)"/></mask>
    <mask id="right-eye-mask" maskUnits="userSpaceOnUse" x="816" y="497" width="135" height="112"><ellipse cx="882" cy="551" rx="53" ry="33" fill="white" filter="url(#soft-eye)"/></mask>
    <image id="d-art" href="assets/cat-d.png" width="1254" height="1254"/>
    <image id="closed-art" href="assets/cat-closed.png" width="1254" height="1254"/>`;
  const layerMarkup = {
    background: '<image href="assets/empty-bed.png" width="1254" height="1254"/>',
    cat: '<use href="#d-art" clip-path="url(#cat-clip)"/>',
    leftEye: '<use href="#closed-art" mask="url(#left-eye-mask)"/>',
    rightEye: '<use href="#closed-art" mask="url(#right-eye-mask)"/>',
    foreground: '<use href="#d-art" clip-path="url(#front-clip)"/>'
  };
  function scene() {
    return `<svg id="cat-scene" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${W}" aria-label="蓝绿色猫窝里的一只三花猫" role="group">
      <defs>${definitions}</defs>
      <g data-layer="background">${layerMarkup.background}</g>
      <g id="breathing-cat">
        <g data-layer="cat">${layerMarkup.cat}</g>
        <g id="eyelids" clip-path="url(#eyelid-wipe)"><g data-layer="leftEye">${layerMarkup.leftEye}</g><g data-layer="rightEye">${layerMarkup.rightEye}</g></g>
      </g>
      <g data-layer="foreground">${layerMarkup.foreground}</g>
      <ellipse id="head-hit" cx="782" cy="436" rx="242" ry="180" fill="transparent" tabindex="0" role="button" aria-label="摸摸猫的头"/>
    </svg>`;
  }
  root.CatArt = {definitions, layerMarkup, scene};
  if (typeof module !== 'undefined') module.exports = root.CatArt;
})(globalThis);
