import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {readPackage, canonical} from './data-contract.js';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const equal = (a,b) => JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
export const signingBuild = {defines:['CBT','AUTOWIKI'],warningsAsErrors:false,ignoreWarningCodes:[],namedDmVersion:null,runtimeParameters:['log-directory=ci']};

/** Read committed blobs only. Never source dependencies.sh or execute downloaded code. */
export function signingSource(repository,commit) {
 if(!/^[a-f0-9]{40}$/.test(commit||''))throw new Error('Signing requires an exact workflow commit');
 const git = args => execFileSync('git',['-C',repository,...args],{stdio:['ignore','pipe','pipe'],timeout:15000,maxBuffer:64*1024*1024});
 if(git(['rev-parse','HEAD']).toString().trim()!==commit)throw new Error('Trusted checkout differs from workflow commit');
 const blob = name => git(['show',commit+':'+name]);
 const names=git(['ls-tree','-r','--name-only','-z',commit,'--','config/']).toString('utf8').split('\0').filter(name=>/\.(txt|json|toml)$/i.test(name)).sort();
 const dependencies=blob('dependencies.sh').toString('utf8');
 const version=key=>{const matches=[...dependencies.matchAll(new RegExp('^export '+key+'=(\\d+)\\r?$','gm'))];if(matches.length!==1)throw new Error('Ambiguous committed BYOND version');return matches[0][1];};
 return {commit,tree:git(['rev-parse',commit+'^{tree}']).toString().trim(),configurationInputs:names.map(name=>({name,sha256:hash(blob(name))})),exporterSha256:hash(blob('code/modules/autowiki/structured.dm')),byond:version('BYOND_MAJOR')+'.'+version('BYOND_MINOR')};
}

export function validateSigningIdentity(manifest,source) {
 const p=manifest.provenance;
 if(manifest.publicationReady!==true||manifest.profile!=='source-defaults'||manifest.source?.commit!==source.commit||p?.commit!==source.commit||p.dirty!==false)throw new Error('Candidate is not a clean package from the workflow commit');
 if(!equal(p.configurationInputs,source.configurationInputs)||p.exporterSha256!==source.exporterSha256)throw new Error('Candidate source inputs differ from committed blobs');
 if(p.workingDiffSha256!==hash('')||!equal(p.untracked,[])||!equal(p.build,signingBuild))throw new Error('Candidate generation parameters differ from the hosted build');
 if(manifest.execution?.compiler!==source.byond||manifest.execution?.runtime!==source.byond||!/^[a-f0-9]{64}$/.test(p.compiler?.sha256||''))throw new Error('Candidate compiler identity is incomplete or differs from source requirements');
}

export async function checkSigningInput(directory,repository,commit) {
 const source=signingSource(repository,commit);
 const contents=await readPackage(directory);
 validateSigningIdentity(contents.manifest,source);
 const allowed=new Set(['manifest.json','icons',...contents.manifest.datasets.map(d=>d.filename)]);
 const entries=await fs.readdir(directory,{withFileTypes:true});
 if(entries.length!==allowed.size||entries.some(e=>!allowed.has(e.name)||(e.name==='icons'?!e.isDirectory():!e.isFile())))throw new Error('Unexpected files in signing candidate');
 return {commit:source.commit,tree:source.tree,manifestDigest:hash(await fs.readFile(path.join(directory,'manifest.json'))),records:contents.records.length,icons:contents.manifest.icons.length,scope:'Package integrity and committed source metadata; not an independent reproduction of gameplay facts.'};
}

if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 const [directory,commit]=process.argv.slice(2);
 try{if(!directory)throw new Error('Usage: node check-signing-input.js <candidate directory> <workflow commit>');console.log(JSON.stringify(await checkSigningInput(directory,process.cwd(),commit)));}
 catch(error){console.error(error.status!==undefined?'Committed source verification failed.':error.message);process.exitCode=1;}
}
