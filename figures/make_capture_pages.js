// make_capture_pages.js — for each figure panel, copy the archived FIXED page tree and set only the form's initial values
// (the <option selected> and the inputs' value="" attributes) to the worked-example inputs, i.e. what a user would type.
// The page then runs its own runCalc() on load. Nothing else in the page is changed (a diff is written per panel).
//   node figures/make_capture_pages.js
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..'), src = path.join(root, 'app', 'fixed');
const PANELS = [
  { name: 'fig1a_W06_nonsurvivors', scenario: 'C3', n: '84', a: '', q1: '64', m: '71', q3: '80', b: '' },
  { name: 'fig1b_W06_survivors', scenario: 'C3', n: '214', a: '', q1: '37', m: '51', q3: '63', b: '' },
  { name: 'fig2_invalid_n', scenario: 'C3', n: '0', a: '', q1: '37', m: '51', q3: '63', b: '' },
];
const copy = (s, d) => { fs.mkdirSync(d, { recursive: true });
  for (const e of fs.readdirSync(s, { withFileTypes: true })) e.isDirectory() ? copy(path.join(s, e.name), path.join(d, e.name)) : fs.copyFileSync(path.join(s, e.name), path.join(d, e.name)); };
for (const p of PANELS) {
  const d = path.join(root, 'figures', 'pages', p.name); copy(src, d);
  const f = path.join(d, 'median-to-mean', 'index.html'); const orig = fs.readFileSync(f, 'utf8'); let h = orig;
  h = h.replace(/<option value="C1">/, '<option value="C1">').replace(`<option value="${p.scenario}">`, `<option value="${p.scenario}" selected>`);
  for (const k of ['n', 'a', 'q1', 'm', 'q3', 'b']) {
    const re = new RegExp(`(<input id="${k}" [^>]*?value=")[^"]*(")`);
    if (!re.test(h)) throw Error('input not found: ' + k); h = h.replace(re, `$1${p[k]}$2`);
  }
  fs.writeFileSync(f, h);
  const a = orig.split('\n'), b = h.split('\n'); const diff = [];
  a.forEach((l, i) => { if (l !== b[i]) diff.push(`line ${i + 1}\n- ${l.trim()}\n+ ${b[i].trim()}`); });
  fs.writeFileSync(path.join(root, 'figures', 'pages', p.name + '.diff.txt'), diff.join('\n') + '\n');
  console.log(`${p.name}: ${diff.length} changed lines`);
}
