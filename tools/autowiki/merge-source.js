import fs from 'node:fs/promises';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {sourceDeployment} from './tgs.js';

/** Reconstruct Git trees in a separate object store. Never check out or execute game inputs. */
export async function reproduceSource(deployment,repository,directory) {
 for(const value of [deployment.commit,deployment.sourceTree,deployment.originCommit])if(!/^[a-f0-9]{40}$/.test(value||''))throw new Error('Exact deployed commit, source tree and origin are required');
 if(!Array.isArray(deployment.mergeIdentities)||deployment.mergeIdentities.length!==deployment.testMerges||deployment.mergeIdentities.length>128)throw new Error('Complete pinned merge identities are required');
 const seen=new Set();
 for(const merge of deployment.mergeIdentities){if(!Number.isSafeInteger(merge.number)||merge.number<=0||!/^[a-f0-9]{40}$/.test(merge.commit||'')||seen.has(merge.number))throw new Error('Invalid pinned merge');seen.add(merge.number);}
 if(!path.isAbsolute(repository)||!path.isAbsolute(directory))throw new Error('Use absolute local source and output directories');
 const source=await fs.realpath(repository);await fs.mkdir(directory,{recursive:false});
 const empty=path.join(directory,'empty');await fs.mkdir(empty);const globalConfig=path.join(empty,'config');await fs.writeFile(globalConfig,'');
 const env={...process.env};for(const key of Object.keys(env))if(key.startsWith('GIT_'))delete env[key];
 Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:globalConfig,GIT_TERMINAL_PROMPT:'0',GIT_AUTHOR_NAME:'Autowiki verification',GIT_AUTHOR_EMAIL:'autowiki@example.invalid',GIT_COMMITTER_NAME:'Autowiki verification',GIT_COMMITTER_EMAIL:'autowiki@example.invalid',GIT_AUTHOR_DATE:'2000-01-01T00:00:00Z',GIT_COMMITTER_DATE:'2000-01-01T00:00:00Z'});
 const git=(args,cwd=directory)=>execFileSync('git',['-c','core.hooksPath='+empty,'-c','core.fsmonitor=false','-c','init.templateDir='+empty,...args],{cwd,env,encoding:'utf8',stdio:['ignore','pipe','pipe'],maxBuffer:8*1024*1024,timeout:120000}).trim();
 const objects=path.join(directory,'source');
 try{
  git(['clone','--local','--shared','--no-checkout','--no-recurse-submodules','--',source,objects]);
  const deployedTree=git(['rev-parse','--verify',deployment.commit+'^{tree}'],objects);
  if(deployedTree!==deployment.sourceTree)throw new Error('Deployed source object differs from observation');
  let current=deployment.originCommit;const steps=[];
  for(const merge of deployment.mergeIdentities){
   const tree=git(['merge-tree','--write-tree','--no-messages',current,merge.commit],objects);
   if(!/^[a-f0-9]{40}$/.test(tree))throw new Error('Merge did not produce one complete tree');
   current=git(['-c','commit.gpgSign=false','commit-tree',tree,'-p',current,'-p',merge.commit,'-m','Synthetic source verification'],objects);
   steps.push({number:merge.number,commit:merge.commit,tree});
  }
  const actualTree=git(['rev-parse','--verify',current+'^{tree}'],objects);
  const result={version:1,deployment:deployment.id,observedAt:deployment.observedAt??null,deployedCommit:deployment.commit,originCommit:deployment.originCommit,expectedTree:deployment.sourceTree,actualTree,steps,matches:actualTree===deployment.sourceTree,publicationReady:false,scope:'Git source-tree equivalence only. No game code was executed and no builder attestation was issued.'};
  await fs.writeFile(path.join(directory,'result.json'),JSON.stringify(result,null,2)+'\n');return result;
 }catch(error){
  const result={version:1,deployment:deployment.id,expectedTree:deployment.sourceTree,matches:false,publicationReady:false,error:error.status!==undefined?'Git could not reconstruct a conflict-free pinned source tree.':error.message};
  await fs.writeFile(path.join(directory,'result.json'),JSON.stringify(result,null,2)+'\n');throw new Error(result.error);
 }
}

if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 const [configFile,output]=process.argv.slice(2);if(!configFile||!output)throw new Error('Usage: node merge-source.js <private receiver configuration> <new absolute verification directory>');
 const config=JSON.parse(await fs.readFile(configFile,'utf8'));
 try{const deployment=await sourceDeployment(config.tgs);const result=await reproduceSource(deployment,config.tgs.repository,output);console.log(JSON.stringify(result));if(!result.matches)process.exitCode=1;}
 catch(error){console.error(error.code?'Source verification failed; inspect protected local configuration.':error.message);process.exitCode=1;}
}
