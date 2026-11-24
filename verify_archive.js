// verify_archive.js — integrity of the archive (run from the archive root):  node verify_archive.js
//  1. every file listed in MANIFEST.sha256 exists with that hash, and no unlisted file exists (except .git, node_modules);
//  2. each app snapshot matches its SHA256SUMS and records a 40-hex commit;
//  3. each capture names the page it ran and that page's sha256 equals the snapshot's index.html hash;
//  4. harness/cases.json equals what harness/make_cases.js builds from corpus/ and its count matches every capture.
// Prints "VERIFY OK k/k" or "VERIFY FAIL" with the failing items; exit 1 on any failure.
const fs = require('fs'), path = require('path'), crypto = require('crypto'), { execFileSync } = require('child_process');
const root = __dirname, fails = [], oks = [];
const sha = f => crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const ok = (c, m) => (c ? oks : fails).push(m);
const walk = d => fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.name === '.git' || e.name === 'node_modules' ? []
  : e.isDirectory() ? walk(path.join(d, e.name)) : [path.relative(root, path.join(d, e.name)).split(path.sep).join('/')]);

const man = fs.readFileSync(path.join(root, 'MANIFEST.sha256'), 'utf8').trim().split('\n').map(l => l.split(/\s+/, 2));
const listed = new Set(man.map(x => x[1]));
for (const [h, f] of man) ok(fs.existsSync(path.join(root, f)) && sha(path.join(root, f)) === h, `manifest ${f}`);
for (const f of walk(root)) if (f !== 'MANIFEST.sha256') ok(listed.has(f), `listed in manifest: ${f}`);

for (const snap of ['original', 'fixed']) {
  const d = path.join(root, 'app', snap);
  for (const l of fs.readFileSync(path.join(d, 'SHA256SUMS'), 'utf8').trim().split('\n')) {
    const [h, f] = l.split(/\s+/, 2); ok(sha(path.join(d, f)) === h, `app/${snap}/${f} sha256`);
  }
  ok(/^[0-9a-f]{40}$/.test(fs.readFileSync(path.join(d, 'COMMIT'), 'utf8').trim()), `app/${snap}/COMMIT`);
  const capf = path.join(root, 'captured', `app_${snap}.json`), cap = JSON.parse(fs.readFileSync(capf, 'utf8'));
  ok(path.resolve(path.dirname(capf), cap.page) === path.join(d, 'median-to-mean', 'index.html'), `captured/app_${snap}.json page path`);
  ok(cap.page_sha256 === sha(path.join(d, 'median-to-mean', 'index.html')), `captured/app_${snap}.json page sha256`);
  const cases = JSON.parse(fs.readFileSync(path.join(root, 'harness', 'cases.json'), 'utf8'));
  ok(cap.n_cases === cases.length && cap.results.length === cases.length, `captured/app_${snap}.json count ${cap.n_cases}`);
}
const before = sha(path.join(root, 'harness', 'cases.json'));
const tmp = fs.readFileSync(path.join(root, 'harness', 'cases.json'));
execFileSync(process.execPath, [path.join(root, 'harness', 'make_cases.js')], { stdio: 'ignore' });
ok(sha(path.join(root, 'harness', 'cases.json')) === before, 'harness/cases.json rebuilt identically from corpus/');
fs.writeFileSync(path.join(root, 'harness', 'cases.json'), tmp);

if (fails.length) { console.log('VERIFY FAIL'); fails.forEach(f => console.log('  FAIL ' + f)); process.exit(1); }
console.log(`VERIFY OK ${oks.length}/${oks.length}`);
