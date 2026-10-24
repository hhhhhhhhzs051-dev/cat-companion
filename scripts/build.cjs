const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const out = process.env.CAT_PREVIEW_OUT || path.join(root,'reports/releases/猫咪互动小样');
fs.mkdirSync(path.join(out, '分层素材'), {recursive:true});

const read = name => name === 'copy-default.js' ? 'globalThis.CAT_COPY ??= '+fs.readFileSync(path.join(root,'src','cat-copy.json'),'utf8')+';' : fs.readFileSync(path.join(root,'src',name),'utf8');
const embed = text => text.replace(/assets\/(cat-d|cat-closed|empty-bed|bed-complete-v2)\.png/g, name => 'data:image/png;base64,' + fs.readFileSync(path.join(root,'src',name)).toString('base64'));
let html = read('index.html').replace('<link rel="stylesheet" href="style.css">',()=>'<style>'+read('style.css')+'</style>');
for (const name of ['state.js','copy-default.js','copy-config.js','companion.js','artwork.js','app.js']) html = html.replace(`<script src="${name}"></script>`,()=>'<script>'+embed(read(name))+'</script>');
fs.writeFileSync(path.join(out,'陪你一会儿.html'), html);
fs.writeFileSync(path.join(out,'分层检查.html'), html.replace('<body>','<body data-inspect="true">'));
const art = require('../src/artwork.js');
for (const [name, markup] of Object.entries(art.layerMarkup)) {
  fs.writeFileSync(path.join(out,'分层素材',name+'.svg'),embed(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1254 1254" width="1254" height="1254"><defs>${art.definitions}</defs>${markup}</svg>`));
}
console.log('Built preview, inspector, and 5 self-contained SVG layers: '+out);
