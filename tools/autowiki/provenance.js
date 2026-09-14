import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function configurationInputs(repository) {
 const result = [];
 const walk = directory => {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
   const filename=path.join(directory,entry.name);
   if(entry.isDirectory())walk(filename);
   else if(entry.isFile()&&/\.(txt|json|toml)$/i.test(entry.name)) result.push({name:path.relative(repository,filename).replaceAll('\\','/'),sha256:hash(fs.readFileSync(filename))});
  }
 };
 walk(path.join(repository,'config'));
 return result.sort((a,b)=>a.name<b.name?-1:a.name>b.name?1:0);
}
export function sourceState(repository = root, build = { defines: ['CBT','AUTOWIKI'] }) {
 const git = args => execFileSync('git', args, { cwd: repository, maxBuffer: 128 * 1024 * 1024 });
 const commit = git(['rev-parse', 'HEAD']).toString().trim();
 const diff = git(['diff', 'HEAD', '--binary', '--no-ext-diff']);
 const untracked = git(['ls-files', '--others', '--exclude-standard', '-z']).toString().split('\0').filter(Boolean).sort().map(name => ({name, sha256: hash(fs.readFileSync(path.join(repository, name)))}));
 const inputs=configurationInputs(repository);
 const compiler=process.env.DM_EXE&&fs.existsSync(process.env.DM_EXE)?{sha256:hash(fs.readFileSync(process.env.DM_EXE))}:null;
 return { configurationInputs:inputs,compiler,build, commit, dirty: diff.length > 0 || untracked.length > 0, workingDiffSha256: hash(diff), untracked, exporterSha256: hash(fs.readFileSync(path.join(repository, 'code/modules/autowiki/structured.dm'))) };
}
export function verifyProvenance(filename, repository = root) {
 const before = JSON.parse(fs.readFileSync(filename, 'utf8')), after = sourceState(repository, before.build);
 if (JSON.stringify(before) !== JSON.stringify(after)) throw new Error('Source changed during generation; regenerate before packaging');
 return before;
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
 const [mode, filename, parameters] = process.argv.slice(2);
 if (!filename || !['capture', 'verify'].includes(mode)) throw new Error('Usage: provenance.js capture|verify <file>');
 if (mode === 'capture') { fs.mkdirSync(path.dirname(filename), { recursive: true }); fs.writeFileSync(filename, JSON.stringify(sourceState(root, parameters ? JSON.parse(parameters) : undefined), null, 2) + '\n'); }
 else verifyProvenance(filename);
}
