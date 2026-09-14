import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { sourceDeployment } from './tgs.js';
import { publish } from './publish.js';
import { retrieveArtifact } from './artifact-source.js';
import {matchesDeployment} from './source-binding.js';
import {requestMissingBuild} from './build-request.js';

/** A bounded cycle for the existing operations scheduler; no embedded credentials. */
export async function receive(config,dependencies={}) {
 for(const field of ['inbox','statusFile'])if(!path.isAbsolute(config[field]||''))throw new Error(field+' must be an absolute local path');
 await fs.mkdir(path.dirname(config.statusFile),{recursive:true});
 const lock=config.statusFile+'.lock';
 try{await fs.mkdir(lock);}catch(error){if(error.code==='EEXIST')return {state:'busy',message:'Another receiver cycle owns the lock.'};throw error;}
 try{return await receiveLocked(config,dependencies);}finally{await fs.rmdir(lock);}
}
async function receiveLocked(config,dependencies) {
 const startedAt=new Date().toISOString();let status;
 try{
  const deployment=await (dependencies.deployment||sourceDeployment)(config.tgs);
  const entries=await fs.readdir(config.inbox,{withFileTypes:true});if(entries.length>200)throw new Error('Inbox exceeds its bounded size');
  const candidates=[];
  for(const entry of entries){if(!entry.isDirectory())continue;const directory=path.join(config.inbox,entry.name),filename=path.join(directory,'manifest.json');let stat;try{stat=await fs.stat(filename);}catch(e){if(e.code==='ENOENT')continue;throw e;}if(stat.size>64*1024*1024)throw new Error('Manifest exceeds size limit');const manifest=JSON.parse(await fs.readFile(filename,'utf8'));if(await matchesDeployment(directory,manifest,deployment,config))candidates.push(directory);}
  if(candidates.length>1)throw new Error('Multiple packages claim the active commit; retain one reviewed candidate');
  let retrieved;
  if(!candidates.length&&config.artifactSource){retrieved=await (dependencies.retrieve||retrieveArtifact)(deployment,config);if(retrieved.directory)candidates.push(retrieved.directory);}
  let requested;
  if(!candidates.length&&config.artifactSource&&config.buildRequests?.enabled===true&&['no-matching-run','no-package-artifact','expired-artifact','test-merge-build'].includes(retrieved?.state))requested=await (dependencies.requestBuild||requestMissingBuild)(deployment,config);
  const base={version:1,checkedAt:startedAt,commit:deployment.commit,engine:deployment.runtime,deployment:deployment.id,testMerges:deployment.testMerges??0,configurationScope:deployment.configurationScope,...(retrieved?{artifactState:retrieved.state}:{}),...(requested&&requested.state!=='disabled'?{artifactState:requested.state,...(requested.runId?{buildRunId:requested.runId}:{})}:{})};
  if(!candidates.length)status={...base,state:'awaiting-package',message:'Waiting for a trusted package for the running game build.'};
  else {const result=await (dependencies.publish||publish)(candidates[0],config);status=result.reviewRequired?{...base,state:'review-required',build:result.reviewRequired,message:'The authenticated package needs editorial review. The active reference was retained.'}:{...base,state:'published',build:result.active,message:'The package for the running game build is active.'};}
 }catch(error){status={version:1,checkedAt:startedAt,state:'failed',message:'Publication checks failed. The active reference was retained; inspect the protected receiver log.'};if(dependencies.log)dependencies.log(error);}
 await fs.mkdir(path.dirname(config.statusFile),{recursive:true});const temporary=config.statusFile+'.'+process.pid+'.pending';await fs.writeFile(temporary,JSON.stringify(status)+'\n');await fs.rename(temporary,config.statusFile);return status;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 try{const config=JSON.parse(await fs.readFile(process.argv[2],'utf8'));const result=await receive(config,{log:error=>console.error(error.code?'Receiver I/O or subprocess failed ('+error.code+').':error.message)});console.log(JSON.stringify(result));if(result.state==='failed')process.exitCode=1;}
 catch{console.error('Receiver configuration or status storage failed.');process.exitCode=1;}
}
