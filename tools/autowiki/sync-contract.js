import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const directory = path.dirname(fileURLToPath(import.meta.url));
const source = fs.readFileSync(path.join(directory, 'contract.json'));
const target = path.join(directory, 'mediawiki/MeridianAutowiki/contract.json');
if (process.argv.includes('--write')) fs.writeFileSync(target, source);
else if (!fs.existsSync(target) || !source.equals(fs.readFileSync(target))) throw new Error('Wiki contract differs: run node tools/autowiki/sync-contract.js --write');
