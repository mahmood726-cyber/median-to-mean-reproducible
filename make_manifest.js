// make_manifest.js — write MANIFEST.sha256 for every archive file (except .git, node_modules and the manifest itself).
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const root = __dirname;
const walk = d => fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.name === '.git' || e.name === 'node_modules' ? []
  : e.isDirectory() ? walk(path.join(d, e.name)) : [path.relative(root, path.join(d, e.name)).split(path.sep).join('/')]);
const files = walk(root).filter(f => f !== 'MANIFEST.sha256').sort();
fs.writeFileSync(path.join(root, 'MANIFEST.sha256'), files.map(f =>
  crypto.createHash('sha256').update(fs.readFileSync(path.join(root, f))).digest('hex') + '  ' + f).join('\n') + '\n');
console.log(`MANIFEST.sha256: ${files.length} files`);
