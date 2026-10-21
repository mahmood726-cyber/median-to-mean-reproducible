// worked_summary.js — descriptive summary of the worked example (for the paper's Use case): results/worked_summary.json
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const L = fs.readFileSync(path.join(root, 'results', 'worked_example_table.csv'), 'utf8').replace(/\r/g, '').trim().split('\n');
const split = s => s.match(/("([^"]|"")*"|[^,]*)(,|$)/g).slice(0, -1).map(x => x.replace(/,$/, '').replace(/^"|"$/g, ''));
const h = split(L[0]); const R = L.slice(1).map(l => { const v = split(l); const o = {}; h.forEach((k, i) => o[k] = v[i]); return o; });
const num = x => Number(x), ok = x => x !== 'NA' && x !== '';
const absd = (a, b) => R.filter(r => ok(r[a]) && ok(r[b])).map(r => Math.abs(num(r[a]) - num(r[b])));
const rng = v => ({ n: v.length, min: Math.min(...v), max: Math.max(...v), median: v.slice().sort((x, y) => x - y)[Math.floor(v.length / 2)] });
const out = {
  study_groups: R.length, studies: new Set(R.map(r => r.study)).size,
  n_range: rng(R.map(r => num(r.n))),
  abs_luo_minus_wan_mean: rng(absd('app_luo_mean', 'app_wan_mean')),
  abs_luo_mean_minus_qe_mean: rng(absd('app_luo_mean', 'qe_mean')),
  abs_wan_sd_minus_qe_sd: rng(absd('app_sd', 'qe_sd')),
  abs_luo_mean_minus_bc_mean: rng(absd('app_luo_mean', 'bc_mean')),
  abs_wan_sd_minus_bc_sd: rng(absd('app_sd', 'bc_sd')),
  qe_missing: R.filter(r => !ok(r.qe_mean)).length, bc_missing: R.filter(r => !ok(r.bc_mean)).length,
  W06: R.filter(r => r.id.startsWith('W06')),
};
fs.writeFileSync(path.join(root, 'results', 'worked_summary.json'), JSON.stringify(out, null, 1));
console.log(JSON.stringify(out, null, 1));
