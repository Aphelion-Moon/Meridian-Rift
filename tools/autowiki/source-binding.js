import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
const sha=value=>createHash('sha256').update(value).digest('hex');
const commit=value=>typeof value==='string'&&/^[a-f0-9]{40}$/.test(value);

/** A canonical, bounded plan contains identities, never shell commands or moving refs. */
export function sourcePlan(value) {
 if(!value||value.version!==1||!commit(value.originCommit)||!commit(value.sourceTree)||!Array.isArray(value.merges)||value.merges.length<1||value.merges.length>128)throw new Error('Incomplete test-merge source plan');
 const numbers=new Set();
 const merges=value.merges.map(m=>{if(!m||!Number.isSafeInteger(m.number)||m.number<=0||!commit(m.commit)||numbers.has(m.number))throw new Error('Invalid pinned test merge');numbers.add(m.number);return {number:m.number,commit:m.commit};});
 return {version:1,originCommit:value.originCommit,sourceTree:value.sourceTree,merges};
}
export function deploymentPlan(deployment) {
 if(!Array.isArray(deployment.mergeIdentities)||deployment.testMerges!==deployment.mergeIdentities.length)throw new Error('Active deployment lacks pinned merge evidence');
 return sourcePlan({...deployment,version:1,merges:deployment.mergeIdentities});
}
export const planDigest=value=>sha(JSON.stringify(sourcePlan(value)));
export function testMergeArtifact(deployment) {return 'autowiki-merged-'+planDigest(deploymentPlan(deployment));}
export function builderCommit(config) {
 const value=config.testMergeBuilderCommit;
 if(!commit(value))throw new Error('A reviewed test-merge builder commit must be pinned in receiver configuration');
 return value;
}
export function builderRef(config) {
 const value=config.testMergeBuilderRef??'refs/heads/master';
 if(value!=='refs/heads/master'&&(!/^refs\/tags\/autowiki-builder-[A-Za-z0-9][A-Za-z0-9._-]{0,80}$/.test(value)||value.includes('..')||value.endsWith('.')||value.endsWith('.lock')))throw new Error('Use master or an approved Autowiki builder release tag');
 return value;
}
export function builderRunBranch(run,config) {
 const ref=builderRef(config);
 // A tag run may omit head_branch; signature verification still pins its exact source ref.
 return ref==='refs/heads/master'?run.head_branch==='master':run.head_branch===ref.slice('refs/tags/'.length)||run.head_branch===null;
}
export function builderRequestKey(deployment,config) {
 const ref=builderRef(config);
 return sha(builderCommit(config)+(ref==='refs/heads/master'?'':'@'+ref)+':'+planDigest(deploymentPlan(deployment)));
}
export async function readSourceBinding(directory) {
 const file=path.join(directory,'source-binding.json'),stat=await fs.lstat(file);
 if(!stat.isFile()||stat.size>65536)throw new Error('Invalid source binding file');
 const bytes=await fs.readFile(file);return {file,bytes,binding:JSON.parse(bytes)};
}
/** Data comparison only. Caller must authenticate the binding before issuing any receipt. */
export function validateSourceBinding(binding,manifestBytes,deployment,config) {
 const plan=deploymentPlan(deployment),manifest=JSON.parse(manifestBytes);
 if(binding.version!==1||binding.kind!=='meridian-autowiki-test-merge'||binding.builderCommit!==builderCommit(config)||binding.manifestDigest!==sha(manifestBytes))throw new Error('Source binding does not cover this package and trusted builder');
 if((binding.builderRef??'refs/heads/master')!==builderRef(config))throw new Error('Signed builder reference differs from approval');
 if(planDigest(binding.plan)!==planDigest(plan)||binding.sourceTree!==deployment.sourceTree)throw new Error('Source binding differs from the running merged source');
 if(!commit(binding.generatedCommit)||manifest.source?.commit!==binding.generatedCommit||manifest.provenance?.commit!==binding.generatedCommit)throw new Error('Generated commit differs from the signed source binding');
 const reconstruction=manifest.source.reconstruction;
 if(reconstruction?.builderCommit!==binding.builderCommit||reconstruction?.tree!==binding.sourceTree||reconstruction?.planDigest!==planDigest(plan))throw new Error('Manifest does not bind the reconstruction context');
 if((reconstruction.builderRef??'refs/heads/master')!==builderRef(config))throw new Error('Manifest builder reference differs from approval');
 if(binding.configurationDigest!==deployment.configurationDigest||binding.compiler!==deployment.compiler||binding.runtime!==deployment.runtime)throw new Error('Source binding configuration or engine differs from deployment');
 return binding;
}

/** Candidate selection is only a locator. It cannot authorize signing or publication. */
export async function matchesDeployment(directory,manifest,deployment,config={}) {
 if(manifest.publicationReady!==true||manifest.provenance?.dirty!==false)return false;
 if(!(deployment.testMerges>0))return manifest.source?.commit===deployment.commit;
 try{const {binding}=await readSourceBinding(directory);return (!config.testMergeBuilderCommit||binding.builderCommit===builderCommit(config))&&(binding.builderRef??'refs/heads/master')===builderRef(config)&&planDigest(binding.plan)===planDigest(deploymentPlan(deployment));}
 catch(error){if(error.code==='ENOENT')return false;throw error;}
}
