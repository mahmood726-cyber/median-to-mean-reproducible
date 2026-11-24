// run_app.js — run the median-to-mean page's OWN engine in Node, loading the page exactly as a browser does:
// jsdom parses index.html and executes every <script> (inline and src=) in document order from the page's folder.
//   node run_app.js <page/index.html> <cases.json> <out.json>
// For each case two paths are captured:
//   hook: window.__almM2M(scenario, n, a, q1, m, q3, b)            (the page's pure-compute hook)
//   ui:   set the form fields, click "Estimate", read window.__almLastM2M(), the results table text and the warning text
// Numbers are written with 17 significant digits; null for non-finite / absent.
const fs = require('fs'), path = require('path'), url = require('url');
const { JSDOM, VirtualConsole } = require('jsdom');           // pinned in harness/package.json (NODE_PATH may point to it)
const JSDOM_VERSION = require(require.resolve('jsdom/package.json')).version;

const [pagePath, casesPath, outPath] = process.argv.slice(2);
if (!outPath) { console.error('usage: node run_app.js <index.html> <cases.json> <out.json>'); process.exit(2); }
const cases = JSON.parse(fs.readFileSync(casesPath, 'utf8'));
// finite -> number; non-finite -> "Infinity" / "-Infinity" / "NaN" (kept distinct); non-number -> null
const num = x => typeof x !== 'number' ? null : Number.isFinite(x) ? Number(x.toPrecision(17)) : String(x);
const fld = x => (x === null || x === undefined) ? '' : String(x);

(async () => {
  const errors = [];
  const vc = new VirtualConsole();
  vc.on('jsdomError', e => errors.push('jsdomError: ' + (e && e.message)));
  vc.on('error', (...a) => errors.push('console.error: ' + a.join(' ')));
  const dom = await JSDOM.fromFile(path.resolve(pagePath), {
    runScripts: 'dangerously', resources: 'usable', pretendToBeVisual: true, virtualConsole: vc,
    url: url.pathToFileURL(path.resolve(pagePath)).href,
  });
  await new Promise(res => dom.window.addEventListener('load', res));
  const w = dom.window, d = w.document;
  if (typeof w.__almM2M !== 'function') throw new Error('page hook __almM2M missing');
  const out = [];
  for (const c of cases) {
    // A blank field reaches the page's engine as parseFloat("") = NaN; pass NaN, not JSON null (JS arithmetic reads null as 0).
    const v = x => (x === null || x === undefined) ? NaN : x;
    const h = w.__almM2M(c.scenario, v(c.n), v(c.a), v(c.q1), v(c.m), v(c.q3), v(c.b));
    d.getElementById('scenario').value = c.scenario;
    for (const k of ['n', 'a', 'q1', 'm', 'q3', 'b']) d.getElementById(k).value = fld(c[k]);
    d.getElementById('btn-run').click();
    const L = w.__almLastM2M() || { scenario: null, n: null, estimates: [] };
    const rows = [...d.querySelectorAll('#results-body tr')].map(tr => [...tr.querySelectorAll('td')].map(td => td.textContent));
    out.push({
      id: c.id,
      hook: { wan_mean: num(h.wan.mean), wan_sd: num(h.wan.sd), luo_mean: num(h.luoMean), shi_sd: h.shiSD === null ? null : num(h.shiSD),
              shi_is_null: h.shiSD === null },
      ui: { scenario: L.scenario, n: num(L.n), refused: L.refused === true, estimates: L.estimates.map(e => ({ source: e.source, mean: num(e.mean), sd: num(e.sd) })),
            table: rows, warning: d.getElementById('warn-slot').textContent.trim() },
    });
  }
  const page = path.relative(path.dirname(path.resolve(outPath)), path.resolve(pagePath)).split(path.sep).join('/');
  const sha256 = require('crypto').createHash('sha256').update(fs.readFileSync(pagePath)).digest('hex');
  fs.writeFileSync(outPath, JSON.stringify({ page, page_sha256: sha256, node: process.version, jsdom: JSDOM_VERSION,
    n_cases: out.length, errors, results: out }));
  console.log(`run_app: ${out.length} cases, ${errors.length} page errors -> ${outPath}`);
  w.close();
})().catch(e => { console.error('run_app FAILED:', e && e.stack || e); process.exit(1); });
