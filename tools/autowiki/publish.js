import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { verifyRelease, SemanticReviewRequired } from './release.js';
import { readPackage } from './data-contract.js';
import { sourceDeployment } from './tgs.js';
const hash = data => createHash('sha256').update(data).digest('hex');
/** Called by the deployment pipeline after its authoritative active receipt is written. */
export async function publish(packageRoot, config, dependencies = {}) {
 const verify = dependencies.verify || verifyRelease;
 const run = dependencies.run || ((executable,args,options)=>execFileSync(executable,args,options).toString('utf8'));
 for (const name of ['php','maintenanceRunner','settings','packageStore','deploymentFile']) if (!path.isAbsolute(config[name] || '')) throw new Error(name+' must be an absolute local path');
 const maintenance = (script,args=[]) => {
   if(config.extensionDirectory&&!path.isAbsolute(config.extensionDirectory))throw new Error('extensionDirectory must be an absolute local path');
   const entry=config.extensionDirectory?'./maintenance/'+script+'.php':'MeridianAutowiki:'+script;
   const output=run(config.php,['-d','memory_limit=1G',config.maintenanceRunner,entry,'--conf',config.settings,...args],{...(config.extensionDirectory?{cwd:config.extensionDirectory}:{}),env:{...process.env,MW_WIKI:config.wiki||'meridian'},stdio:['ignore','pipe','pipe'],timeout:1200000});
  // MediaWiki may print a fatal error with exit code zero. A complete expected JSON result is required.
  try{return JSON.parse(output.trim());}catch{throw new Error('Maintenance '+script+' did not return a valid result');}
 };
 const state=maintenance('State');if(typeof state.active!=='string'||(state.active&&!/^[a-f0-9]{64}$/.test(state.active)))throw new Error('Invalid active release state');
 const refreshDeployment=async()=>{
  if(!config.tgs)return;
  const deployment=await (dependencies.deployment || sourceDeployment)(config.tgs);
  await fs.mkdir(path.dirname(config.deploymentFile),{recursive:true});
  const temporary=config.deploymentFile+'.'+process.pid+'.pending';await fs.writeFile(temporary,JSON.stringify(deployment)+'\n',{mode:0o600});await fs.rename(temporary,config.deploymentFile);
 };
 await refreshDeployment();
 const previousPackage=state.active?path.join(config.packageStore,'packages',state.active):undefined;
 if(previousPackage){const bytes=await fs.readFile(path.join(previousPackage,'manifest.json'));if(hash(bytes)!==state.active)throw new Error('The prior active package is unavailable for regression comparison');}
 let receipt,reviewRequired=false;
 try{receipt=await verify(packageRoot,{...config,previousPackage});}
 catch(error){if(!(error instanceof SemanticReviewRequired))throw error;receipt={build:error.build};reviewRequired=true;}
 if(!/^[a-f0-9]{64}$/.test(receipt.build||''))throw new Error('Invalid authenticated package identity');
 const destination=path.join(config.packageStore,'packages',receipt.build);
 await fs.mkdir(path.dirname(destination),{recursive:true});
 try {await fs.access(destination);}catch(error){if(error.code!=='ENOENT')throw error;const temporary=destination+'.'+process.pid+'.pending';await fs.cp(packageRoot,temporary,{recursive:true,errorOnExist:true,force:false});const copied=await readPackage(temporary);if(hash(await fs.readFile(path.join(temporary,'manifest.json')))!==receipt.build||!copied.records.length)throw new Error('Copied package failed verification');await fs.rename(temporary,destination);}
 await readPackage(destination);if(hash(await fs.readFile(path.join(destination,'manifest.json')))!==receipt.build)throw new Error('Stored package identity differs from verification');
 const review=maintenance('Review',['--package',destination]);
 if(review.review!==receipt.build)throw new Error('Review import did not confirm the authenticated build');
 const selectionPlan=maintenance('Selection',['--build',receipt.build]);
 reviewRequired=false;
 try{receipt=await verify(destination,{...config,previousPackage,selectionPlan});}
 catch(error){if(!(error instanceof SemanticReviewRequired))throw error;receipt={build:error.build};reviewRequired=true;}
 const assessment=maintenance('Assessment',['--build',receipt.build]);if(assessment.review!==receipt.build)throw new Error('Assessment did not confirm the reviewed selection');
 if(reviewRequired)return {reviewRequired:receipt.build,active:state.active};
 const plan=JSON.parse(Buffer.from(selectionPlan.bytes,'base64').toString('utf8'));
 if(state.active===receipt.build&&state.publication?.reviewDigest===plan.reviewDigest&&state.publication?.id===plan.expectedPublication)return {active:receipt.build,delivery:'unchanged'};
 let result;
 if(config.tgs){
  // Preparation can outlast a round. Recheck TGS and the artifact before activation.
  const prepared=maintenance('Publish',['--package',destination,'--expected',state.active||'none','--prepare-only']);
  if(prepared.prepared!==receipt.build)throw new Error('Preparation did not confirm the verified build');
  await refreshDeployment();const fresh=maintenance('Selection',['--build',receipt.build]);if(fresh.digest!==selectionPlan.digest)throw new Error('Human selection or active publication changed during preparation');await verify(destination,{...config,previousPackage,selectionPlan:fresh});
  result=maintenance('Activate',['--build',receipt.build,'--expected',state.active||'none']);
 }else result=maintenance('Publish',['--package',destination,'--expected',state.active||'none']);
 if(result.active!==receipt.build)throw new Error('Publication did not confirm the verified build');
 return result;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 try{const [packageRoot,configFile]=process.argv.slice(2);if(!packageRoot||!configFile)throw new Error('Usage: node publish.js <attested package> <private deployment configuration.json>');console.log(JSON.stringify(await publish(packageRoot,JSON.parse(await fs.readFile(configFile,'utf8')))));}
 catch(error){console.error(error.status!==undefined?'Publication command failed; inspect protected server logs.':error.message);process.exitCode=1;}
}
