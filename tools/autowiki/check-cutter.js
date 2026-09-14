import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'tools/autowiki/cutter-debt.json')));
const configs = execFileSync('git', ['ls-files', '-z', '*.png.toml', '*.dmi.toml'], {cwd:root}).toString().split('\0').filter(Boolean);
const missing = [];
for (const config of configs) {
 const source = config.slice(0, -5);
 if (fs.existsSync(path.join(root, source))) continue;
 const output = source.endsWith('.png') ? source.slice(0, -4) + '.dmi' : source.slice(0, -4) + '.png';
 const hash = fs.existsSync(path.join(root, output)) ? createHash('sha256').update(fs.readFileSync(path.join(root, output))).digest('hex') : null;
 const configHash = createHash('sha256').update(fs.readFileSync(path.join(root, config))).digest('hex');
 if (!baseline.some(row => row.config === config && row.output === output && row.sha256 === hash && row.configSha256 === configHash)) throw new Error(`Unreviewed or changed cutter source debt: ${config}`);
 missing.push({config, output, sha256:hash, configSha256:configHash});
}
const report = {configs: configs.length, reproducible: configs.length - missing.length, retainedPrebuilt: missing, resolved: baseline.filter(row => !missing.some(m => m.config === row.config)).map(row => row.config)};
if (process.argv[2]) { fs.mkdirSync(path.dirname(process.argv[2]), {recursive:true}); fs.writeFileSync(process.argv[2], JSON.stringify(report, null, 2) + '\n'); }
console.log(JSON.stringify({configs:report.configs, reproducible:report.reproducible, retainedPrebuilt:missing.length, resolved:report.resolved.length}));
