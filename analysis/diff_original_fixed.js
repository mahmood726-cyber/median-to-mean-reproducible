// diff_original_fixed.js — are the original and fixed captures identical (bit-for-bit JSON) for every valid-n configuration?
//   node analysis/diff_original_fixed.js   -> results/original_vs_fixed.txt
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const load = f => JSON.parse(fs.readFileSync(path.join(root, 'captured', f), 'utf8')).results;
const O = load('app_original.json'), F = load('app_fixed.json');
const cases = JSON.parse(fs.readFileSync(path.join(root, 'harness', 'cases.json'), 'utf8'));
const valid = n => typeof n === 'number' && Number.isFinite(n) && n >= 2 && Number.isInteger(n);
let same = 0, diff = 0, invalid = 0; const ex = [];
cases.forEach((c, i) => {
  if (!valid(c.n)) { invalid++; return; }
  const o = JSON.stringify(O[i]), f = JSON.stringify({ ...F[i], ui: { ...F[i].ui } });
  const o2 = JSON.parse(o); o2.ui.refused = F[i].ui.refused;   // the 'refused' field is new in the fixed page (false here)
  if (JSON.stringify(o2) === f) same++; else { diff++; if (ex.length < 5) ex.push(c.id); }
});
const out = `valid-n configurations identical in original and fixed captures: ${same}/${same + diff}` +
  (diff ? `; differing e.g. ${ex.join(', ')}` : '') + `\ninvalid-n configurations (behaviour changed by the fix): ${invalid}\n`;
fs.mkdirSync(path.join(root, 'results'), { recursive: true });
fs.writeFileSync(path.join(root, 'results', 'original_vs_fixed.txt'), out); process.stdout.write(out);
