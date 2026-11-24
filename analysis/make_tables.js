// make_tables.js — paper tables from the archived results (run after validate.R):
//   results/table1_quantities.csv : per quantity, checks/passes before (original page) and after (fixed page), max differences, tolerance
//   results/table2_worked.csv     : the 58 worked-example study-groups (app values = R values; estmeansd QE/BC descriptive)
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
function csv(f) {
  const L = fs.readFileSync(path.join(root, f), 'utf8').replace(/\r/g, '').trim().split('\n');
  const parse = s => { const o = []; let c = '', q = false; for (let i = 0; i < s.length; i++) { const ch = s[i];
    if (ch === '"') { if (q && s[i + 1] === '"') { c += '"'; i++; } else q = !q; } else if (ch === ',' && !q) { o.push(c); c = ''; } else c += ch; }
    o.push(c); return o; };
  const h = parse(L[0]); return L.slice(1).map(r => { const v = parse(r); const o = {}; h.forEach((k, j) => o[k] = v[j]); return o; });
}
const q = s => /[",]/.test(s) ? '"' + String(s).replace(/"/g, '""') + '"' : String(s);
const B = csv('results/summary_app_original.csv'), A = csv('results/summary_app_fixed.csv');
const LABEL = { 'configurations present': 'Configurations present (count and identity)', 'page errors': 'Page script errors',
  'hook wan_mean': 'Wan 2014 mean', 'hook wan_sd': 'Wan 2014 SD', 'hook luo_mean': 'Luo 2018 mean', 'hook shi_sd': 'Shi 2020 SD (C1, C3)',
  'hook shi_sd null (C2)': 'No Shi SD for C2', 'ui scenario and n echoed': 'Export: scenario and n', 'ui row count': 'Result rows (table and export)',
  'ui source label': 'Row source labels', 'ui mean': 'Exported means', 'ui SD': 'Exported SDs', 'table text': 'Displayed table rows (text)',
  'warning text': 'Warning text', 'refusal: no table rows': 'Invalid n: no rows displayed', 'refusal: no exported estimates': 'Invalid n: nothing exported' };
const NUMERIC = new Set(['hook wan_mean', 'hook wan_sd', 'hook luo_mean', 'hook shi_sd', 'ui mean', 'ui SD']);
const rows = [['quantity', 'checks_before', 'passed_before', 'checks_after', 'passed_after', 'max_difference_before', 'max_difference_after', 'tolerance']];
for (const a of A) {
  const b = B.find(x => x.quantity === a.quantity); if (!b) throw Error('missing in original: ' + a.quantity);
  const tot = a.quantity === 'TOTAL', num = NUMERIC.has(a.quantity);
  rows.push([tot ? 'TOTAL' : LABEL[a.quantity], b.checks, b.passed, a.checks, a.passed, num ? b.max_difference : '', num ? a.max_difference : '', tot ? '' : num ? '1e-9' : '0']);
}
fs.writeFileSync(path.join(root, 'results', 'table1_quantities.csv'), rows.map(r => r.map(q).join(',')).join('\n') + '\n');
const W = csv('results/worked_example_table.csv'), f3 = x => Number(x).toFixed(3), f2 = x => x === 'NA' || x === '' ? '—' : Number(x).toFixed(2);
const t2 = [['study', 'group', 'n', 'median_iqr', 'luo_mean', 'wan_sd', 'qe', 'bc']];
for (const r of W) {
  if (r.app_luo_mean !== r.R_luo_mean && Math.abs(r.app_luo_mean - r.R_luo_mean) > 1e-9 * Math.max(1, Math.abs(r.R_luo_mean))) throw Error('app != R ' + r.id);
  t2.push([r.study, r.group, r.n, `${r.median} (${r.q1}–${r.q3})`, f3(r.app_luo_mean), f3(r.app_sd), `${f2(r.qe_mean)} (${f2(r.qe_sd)})`, `${f2(r.bc_mean)} (${f2(r.bc_sd)})`]);
}
fs.writeFileSync(path.join(root, 'results', 'table2_worked.csv'), t2.map(r => r.map(q).join(',')).join('\n') + '\n');
console.log(`table1: ${rows.length - 1} rows; table2: ${t2.length - 1} rows`);
