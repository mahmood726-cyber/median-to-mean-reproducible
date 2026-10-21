// make_cases.js — corpus CSVs -> harness/cases.json (grid, probes, and published examples if present), in that order.
//   node harness/make_cases.js        (run from the archive root)
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
function csv(f) {
  const L = fs.readFileSync(f, 'utf8').replace(/\r/g, '').trim().split('\n');
  const parse = s => { const o = []; let c = '', q = false;
    for (let i = 0; i < s.length; i++) { const ch = s[i];
      if (ch === '"') { if (q && s[i + 1] === '"') { c += '"'; i++; } else q = !q; }
      else if (ch === ',' && !q) { o.push(c); c = ''; } else c += ch; }
    o.push(c); return o; };
  const h = parse(L[0]);
  return L.slice(1).map(r => { const v = parse(r); const o = {}; h.forEach((k, j) => o[k] = v[j]); return o; });
}
const val = s => (s === undefined || s === '' || s === 'NA') ? null : Number(s);
const cases = [];
for (const f of ['grid.csv', 'probes.csv', 'published.csv']) {
  const p = path.join(root, 'corpus', f);
  if (!fs.existsSync(p)) continue;
  const seen = new Set();
  for (const r of csv(p)) {
    if (f === 'published.csv') { if (seen.has(r.case_id)) continue; seen.add(r.case_id); r.id = r.case_id; }
    cases.push({ id: r.id, scenario: r.scenario, n: val(r.n), a: val(r.a), q1: val(r.q1), m: val(r.m), q3: val(r.q3), b: val(r.b) });
  }
}
fs.writeFileSync(path.join(root, 'harness', 'cases.json'), JSON.stringify(cases));
console.log(`make_cases: ${cases.length} configurations -> harness/cases.json`);
// the real-data worked example (PREREG A6) is captured separately
const wf = path.join(root, 'corpus', 'worked_example.csv');
if (fs.existsSync(wf)) {
  const w = csv(wf).map(r => ({ id: r.id, scenario: r.scenario, n: val(r.n), a: val(r.a), q1: val(r.q1), m: val(r.m), q3: val(r.q3), b: val(r.b) }));
  fs.writeFileSync(path.join(root, 'harness', 'cases_worked.json'), JSON.stringify(w));
  console.log(`make_cases: ${w.length} worked-example configurations -> harness/cases_worked.json`);
}
