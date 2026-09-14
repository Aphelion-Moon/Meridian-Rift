import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { readPackage } from './data-contract.js';
import { gate } from './semantic-check.js';
import { githubToken } from './artifact-source.js';
import { decodeSelection, assessSelection, sourceLoader } from './selection-plan.js';
import {readSourceBinding,validateSourceBinding,builderCommit,builderRef} from './source-binding.js';
const sha = value => createHash('sha256').update(value).digest('hex');
export class SemanticReviewRequired extends Error {
 constructor(build,reasons){super('Semantic changes require review: '+[...new Set(reasons.map(r=>r.rule))].join(', '));this.name='SemanticReviewRequired';this.build=build;}
}
export function validateDeployment(manifest, deployment, boundSourceCommit = null) {
 if (!manifest.publicationReady || manifest.provenance?.dirty !== false) throw new Error('A clean generated package is required');
 const expectedCommit=deployment.testMerges>0?boundSourceCommit:deployment.commit;
 if (deployment.version !== 1 || !/^[a-zA-Z0-9._:-]{1,120}$/.test(deployment.id || '') || !/^[a-f0-9]{40}$/.test(deployment.commit||'') || expectedCommit !== manifest.source.commit) throw new Error('Package does not describe the active deployment');
 const inputs = manifest.provenance.configurationInputs;
 if (!Array.isArray(inputs) || deployment.configurationDigest !== sha(JSON.stringify(inputs))) throw new Error('Deployment configuration differs from the documentation fixture');
 if (deployment.compiler !== manifest.execution?.compiler || deployment.runtime !== manifest.execution?.runtime) throw new Error('Compiler or runtime differs from the deployed game');
 if (deployment.configurationScope === 'source-defaults' && manifest.profile !== 'source-defaults') throw new Error('Source-default evidence cannot authorize a runtime-configured export');
 if (deployment.observedAt) {
  const age=Date.now()-Date.parse(deployment.observedAt);
  if(!Number.isFinite(age)||age< -10000||age>120000)throw new Error('Active deployment observation has expired');
 }
 return deployment;
}
/** A deployment-owned receipt and GitHub attestation are both required. No wiki password is used. */
export async function verifyRelease(packageRoot, config, verify) {
 if(!verify){
  const token=await githubToken(config);if(!token)throw new Error('A dedicated GitHub read credential is required for attestation verification');
  const env={...process.env,GH_TOKEN:token,GH_HOST:'github.com',GH_PROMPT_DISABLED:'1'};delete env.GITHUB_TOKEN;delete env.GH_ENTERPRISE_TOKEN;delete env.GITHUB_ENTERPRISE_TOKEN;delete env.GH_DEBUG;
  verify=args=>execFileSync(config.gh||'gh',args,{env,stdio:['ignore','pipe','pipe'],timeout:120000});
 }
 const manifestPath = path.resolve(packageRoot, 'manifest.json');
 const bytes = await fs.readFile(manifestPath), manifest = JSON.parse(bytes);
 const deploymentBytes = await fs.readFile(config.deploymentFile), deployment = JSON.parse(deploymentBytes);
 const sourceBinding=deployment.testMerges>0?await readSourceBinding(packageRoot):null;
 if(sourceBinding)validateSourceBinding(sourceBinding.binding,bytes,deployment,config);
 validateDeployment(manifest,deployment,sourceBinding?.binding.generatedCommit);
 const current = await readPackage(packageRoot), previous = config.previousPackage ? await readPackage(config.previousPackage) : null;
 const baseline = config.baseline ? JSON.parse(await fs.readFile(config.baseline,'utf8')) : [];
 const id=sha(bytes),previousBuild=config.previousPackage?sha(await fs.readFile(path.join(config.previousPackage,'manifest.json'))):'';
 const selected=config.selectionPlan?decodeSelection(config.selectionPlan,id,previousBuild):null;
 const report = selected?(await assessSelection(current,previous,selected.plan,baseline,sourceLoader(config.packageStore))).report:gate(previous,current,baseline);
 const repo = 'Aphelion-Moon/Meridian-Rift';
 if(sourceBinding)verify(['attestation','verify',sourceBinding.file,'--repo',repo,'--signer-workflow',repo+'/.github/workflows/autowiki-test-merges.yml','--source-ref',builderRef(config),'--source-digest',builderCommit(config),'--deny-self-hosted-runners','--format','json']);
 else verify(['attestation','verify',manifestPath,'--repo',repo,'--signer-workflow',repo+'/.github/workflows/autowiki.yml','--source-ref','refs/heads/master','--source-digest',deployment.commit,'--deny-self-hosted-runners','--format','json']);
 // Reject a changed file even if the verification process returned successfully.
 if (!bytes.equals(await fs.readFile(manifestPath)) || !deploymentBytes.equals(await fs.readFile(config.deploymentFile))) throw new Error('Package or deployment changed during verification');
 if(sourceBinding&&!sourceBinding.bytes.equals(await fs.readFile(sourceBinding.file)))throw new Error('Signed source binding changed during verification');
 if(!report.ok)await fs.rm(path.join(config.packageStore,'verified',id+'.json'),{force:true});
 // This data-only report authorizes review, never activation. Keep its complete
 // findings separate from the human revision namespace and public receipt.
 const reportBytes=JSON.stringify({version:1,build:id,previous:previousBuild,...(selected?{selectionDigest:selected.digest}:{}),report})+'\n';
 if(Buffer.byteLength(reportBytes)>64*1024*1024)throw new Error('Publication findings exceed the review size limit');
 const reports=path.join(config.packageStore,'review-reports');await fs.mkdir(reports,{recursive:true});
 const reportFile=path.join(reports,id+'.json'),reportTemp=reportFile+'.tmp';await fs.writeFile(reportTemp,reportBytes);await fs.rename(reportTemp,reportFile);
 const authenticated=path.join(config.packageStore,'authenticated');await fs.mkdir(authenticated,{recursive:true});
 const originFile=path.join(authenticated,id+'.json'),originTemp=originFile+'.tmp';
 await fs.writeFile(originTemp,JSON.stringify({version:1,build:id,commit:deployment.commit,reportDigest:sha(reportBytes),verifiedAt:new Date().toISOString()})+'\n');await fs.rename(originTemp,originFile);
 if(!report.ok)throw new SemanticReviewRequired(id,report.reasons);
 if(selected){const directory=path.join(config.packageStore,'verified-selections');await fs.mkdir(directory,{recursive:true});const file=path.join(directory,id+'.json');await fs.writeFile(file+'.tmp',selected.bytes);await fs.rename(file+'.tmp',file);}
 const receipt = { version:1,build:id,commit:deployment.commit,deployment:deployment.id,deploymentDigest:sha(deploymentBytes),assessmentDigest:sha(reportBytes),...(selected?{selectionDigest:selected.digest}:{}),verifiedAt:new Date().toISOString(),semanticIssues:report.issues.length };
 const directory = path.join(config.packageStore,'verified');await fs.mkdir(directory,{recursive:true});
 const destination=path.join(directory,id+'.json'), temporary=destination+'.tmp';
 await fs.writeFile(temporary,JSON.stringify(receipt,null,2)+'\n');await fs.rename(temporary,destination);
 return receipt;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 const [packageRoot,configFile]=process.argv.slice(2);
 if(!packageRoot||!configFile)throw new Error('Usage: node release.js <package> <private server configuration.json>');
 try{const result=await verifyRelease(packageRoot,JSON.parse(await fs.readFile(configFile,'utf8')));console.log(JSON.stringify(result));}
 catch(error){console.error(error.status!==undefined?'Trusted-builder verification failed; package was not authorized.':error.message);process.exitCode=1;}
}
