import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {checkSigningInput,signingSource} from './check-signing-input.js';
import {sourcePlan,builderCommit,builderRef,planDigest} from './source-binding.js';
import {canonical} from './data-contract.js';
const sha=value=>createHash('sha256').update(value).digest('hex');

/** Called only after reconstruction in a fresh signing job, using trusted builder code. */
export async function bindMergedPackage(directory,sourceDirectory,planValue,trustedBuilderCommit,trustedBuilderRef='refs/heads/master') {
 const plan=sourcePlan(planValue);builderCommit({testMergeBuilderCommit:trustedBuilderCommit});
 const ref=builderRef({testMergeBuilderRef:trustedBuilderRef});
 const {execFileSync}=await import('node:child_process');
 const generatedCommit=execFileSync('git',['-C',sourceDirectory,'rev-parse','HEAD'],{stdio:['ignore','pipe','pipe'],encoding:'utf8',timeout:15000}).trim();
 const source=signingSource(sourceDirectory,generatedCommit);
 if(source.tree!==plan.sourceTree)throw new Error('Signing source differs from requested tree');
 await checkSigningInput(directory,sourceDirectory,generatedCommit);
 // The immutable package ID must distinguish a new trusted builder or merge plan.
 // Otherwise an older binding could occupy the same manifest-addressed directory.
 const manifestFile=path.join(directory,'manifest.json'),manifest=JSON.parse(await fs.readFile(manifestFile,'utf8'));
 manifest.source.reconstruction={builderCommit:trustedBuilderCommit,builderRef:ref,planDigest:planDigest(plan),tree:source.tree};
 const manifestBytes=JSON.stringify(canonical(manifest),null,2)+'\n';await fs.writeFile(manifestFile,manifestBytes);
 const binding={version:1,kind:'meridian-autowiki-test-merge',builderCommit:trustedBuilderCommit,builderRef:ref,plan,sourceTree:source.tree,generatedCommit,manifestDigest:sha(manifestBytes),configurationDigest:sha(JSON.stringify(source.configurationInputs)),compiler:source.byond,runtime:source.byond};
 await fs.writeFile(path.join(directory,'source-binding.json'),JSON.stringify(binding,null,2)+'\n',{flag:'wx'});return binding;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 try{const [directory,source,planFile,commit,ref]=process.argv.slice(2);const stat=await fs.stat(planFile);if(stat.size>65536)throw new Error('Source plan exceeds size limit');console.log(JSON.stringify(await bindMergedPackage(directory,source,JSON.parse(await fs.readFile(planFile,'utf8')),commit,ref)));}
 catch(error){console.error(error.status!==undefined?'Signing source inspection failed.':error.message);process.exitCode=1;}
}
