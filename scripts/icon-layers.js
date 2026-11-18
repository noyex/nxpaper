// Writes the dot layers of Resources/AppIcon.icon: the Fala wallpaper's dot field in perspective.
//   node scripts/icon-layers.js Resources/AppIcon.icon/Assets
const fs = require('fs');
const out = process.argv[2];
// Opacity is baked into the grey level: actool ignores per-element opacity, and the glass background renders as dark grey, so the faintest dots stay above it.
const grey = a => { const v = Math.round(236 * a).toString(16).padStart(2, '0'); return `#${v}${v}${v}`; };
const S = 1024 / 824, map = v => (v - 100) * S;
// Three lit dots along one wave crest, like the green highlight in the Fala wallpaper.
const CREST = new Set(['5,3', '6,2', '7,1']);
let dots = '', green = '';
const R = 11;
for (let i = 0; i < R; i++) {
  const p = i / (R - 1), y0 = 360 + p * p * 520, sp = 44 + p * 76, rad = 5 + p * 17, amp = 8 + p * 44;
  const n = Math.ceil(420 / sp) + 1;
  for (let c = -n; c <= n; c++) {
    const h = Math.sin(c * 0.55 + i * 0.62) * Math.cos(i * 0.4 + c * 0.08);
    const x = map(512 + c * sp), y = map(y0 - h * amp);
    const g = CREST.has(`${i},${c}`);
    const r = ((g ? rad * 1.25 : rad) * S).toFixed(1);
    if (g) green += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r}"/>`;
    else dots += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r}" fill="${grey(0.18 + Math.pow(p, 1.4) * 0.82)}"/>`;
  }
}
const svg = (fill, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><g fill="${fill}">${body}</g></svg>\n`;
fs.writeFileSync(`${out}/dots.svg`, svg('#ececec', dots));
fs.writeFileSync(`${out}/crest.svg`, svg('#1efc1e', green));
