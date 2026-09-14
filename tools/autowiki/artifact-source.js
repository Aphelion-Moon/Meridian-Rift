import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {readPackage} from './data-contract.js';
import {testMergeArtifact,builderCommit,builderRef,builderRunBranch,builderRequestKey,planDigest,deploymentPlan,matchesDeployment} from './source-binding.js';

export const REPOSITORY='Aphelion-Moon/Meridian-Rift';
const API='https://api.github.com', PREFIX='/repos/'+REPOSITORY;
const MAX_ARCHIVE=512*1024*1024;
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const id=value=>Number.isSafeInteger(value)&&value>0;

/** Explicit service credential only. Never borrow desktop GitHub login state. */
export async function githubToken(config) {
 if(!config.githubTokenFile)return '';
 if(!path.isAbsolute(config.githubTokenFile))throw new Error('GitHub credential path must be absolute');
 const stat=await fs.lstat(config.githubTokenFile);
 if(!stat.isFile()||stat.size>4096)throw new Error('Invalid GitHub credential file');
 const token=(await fs.readFile(config.githubTokenFile,'utf8')).trim();
 if(!/^[A-Za-z0-9_]{20,4096}$/.test(token))throw new Error('Invalid GitHub service credential');
 return token;
}

export function githubClient(token,request=fetch) {
 const headers={'Accept':'application/vnd.github+json','User-Agent':'Meridian-Autowiki-Receiver','X-GitHub-Api-Version':'2026-03-10',...(token?{Authorization:'Bearer '+token}:{})};
 const api=async endpoint=>{
  let gitRead=endpoint===PREFIX+'/git/ref/heads/master'||new RegExp('^'+PREFIX+'/git/tags/[a-f0-9]{40}$').test(endpoint);
  if(endpoint.startsWith(PREFIX+'/git/ref/tags/'))gitRead=builderRef({testMergeBuilderRef:'refs/'+endpoint.slice((PREFIX+'/git/ref/').length)}).startsWith('refs/tags/');
  if(!endpoint.startsWith(PREFIX+'/actions/')&&!gitRead)throw new Error('Unexpected artifact API path');
  let response;
  try{response=await request(API+endpoint,{headers,redirect:'manual',signal:AbortSignal.timeout(30000)});}catch{throw new Error('GitHub artifact request failed');}
  if(![200,302].includes(response.status)){await response.body?.cancel();throw new Error('GitHub artifact request failed (HTTP '+response.status+')');}
  return response;
 };
 return {
  async json(endpoint){
   const response=await api(endpoint);if(response.status!==200)throw new Error('Unexpected GitHub API redirect');
   let size=0;const chunks=[];
   for await(const chunk of response.body){size+=chunk.length;if(size>2*1024*1024)throw new Error('GitHub metadata exceeds size limit');chunks.push(chunk);}
   try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new Error('Invalid GitHub artifact metadata');}
  },
  async download(artifact,filename){
   const response=await api(PREFIX+'/actions/artifacts/'+artifact.id+'/zip');
   if(response.status!==302)throw new Error('Expected signed artifact download redirect');
   let url;try{url=new URL(response.headers.get('location'));}catch{throw new Error('Missing artifact download location');}
   if(url.protocol!=='https:'||url.username||url.password||url.port||!['.blob.core.windows.net','.githubusercontent.com'].some(suffix=>url.hostname.endsWith(suffix)))throw new Error('Unexpected artifact storage host');
   // The signed storage request receives no API token and cannot redirect it.
   let download;try{download=await request(url,{redirect:'error',signal:AbortSignal.timeout(180000)});}catch{throw new Error('Artifact storage request failed');}
   if(!download.ok){await download.body?.cancel();throw new Error('Artifact storage request failed');}
   let size=0;const hash=createHash('sha256'),file=await fs.open(filename,'wx');
   try{for await(const chunk of download.body){size+=chunk.length;if(size>MAX_ARCHIVE||size>artifact.size_in_bytes)throw new Error('Artifact download exceeds size limit');hash.update(chunk);await file.writeFile(chunk);}}finally{await file.close();}
   if(size!==artifact.size_in_bytes||'sha256:'+hash.digest('hex')!==artifact.digest)throw new Error('Artifact archive checksum or length differs');
  }
 };
}

/** Selection is a locator, not authorization: publication still verifies attestation. */
export async function findArtifact(deployment,client,config={}) {
 if(!/^[a-f0-9]{40}$/.test(deployment.commit||''))throw new Error('Invalid deployed commit');
 const merged=deployment.testMerges>0;
 if(merged&&!config.testMergeBuilderCommit)return {state:'test-merge-build'};
 const workflowName=merged?'autowiki-test-merges.yml':'autowiki.yml',sourceCommit=merged?builderCommit(config):deployment.commit;
 const artifactName=merged?testMergeArtifact(deployment):'autowiki-publication-'+deployment.commit;
 const workflow=await client.json(PREFIX+'/actions/workflows/'+workflowName);
 if(!id(workflow.id)||workflow.path!=='.github/workflows/'+workflowName||workflow.state!=='active')throw new Error('Unexpected publication workflow');
 let knownRun;
 if(merged&&config.buildRequests?.directory){
  if(!path.isAbsolute(config.buildRequests.directory))throw Error('Build request journal must use an absolute directory');
  const key=builderRequestKey(deployment,config),file=path.join(config.buildRequests.directory,key+'.json');
  try{const stat=await fs.lstat(file);if(!stat.isFile()||stat.size>65536)throw Error('Invalid request journal');const record=JSON.parse(await fs.readFile(file,'utf8'));if(record.version!==1||record.key!==key||record.builderCommit!==sourceCommit||(record.builderRef??'refs/heads/master')!==builderRef(config)||planDigest(record.plan)!==planDigest(deploymentPlan(deployment)))throw Error('Request journal differs from artifact lookup');if(id(record.runId))knownRun=await client.json(PREFIX+'/actions/runs/'+record.runId);}
  catch(error){if(error.code!=='ENOENT')throw error;}
 }
 const branchFilter=!merged||builderRef(config)==='refs/heads/master'?'&branch=master':'';
 const result=knownRun?{workflow_runs:[knownRun],total_count:1}:await client.json(PREFIX+'/actions/workflows/'+workflow.id+'/runs?head_sha='+sourceCommit+branchFilter+'&status=success&per_page=100');
 if(!Array.isArray(result.workflow_runs)||result.workflow_runs.length>100||!merged&&result.total_count>100)throw new Error('Workflow run inventory exceeds its bound');
 const runs=result.workflow_runs.filter(run=>id(run.id)&&run.workflow_id===workflow.id&&run.head_sha===sourceCommit&&(merged?builderRunBranch(run,config):run.head_branch==='master')&&run.status==='completed'&&run.conclusion==='success'&&(merged?['workflow_dispatch']:['push','schedule','workflow_dispatch']).includes(run.event)&&run.repository?.full_name===REPOSITORY&&run.head_repository?.full_name===REPOSITORY).sort((a,b)=>b.id-a.id);
 if(!runs.length)return {state:'no-matching-run'};
 for(const run of runs.slice(0,merged?20:1)){
 const list=await client.json(PREFIX+'/actions/runs/'+run.id+'/artifacts?per_page=100');
 if(!Array.isArray(list.artifacts)||list.artifacts.length>100||list.total_count>100)throw new Error('Artifact inventory exceeds its bound');
 const matching=list.artifacts.filter(a=>a.name===artifactName);
 if(matching.length>1)throw new Error('Ambiguous publication artifacts');
 if(!matching.length)continue;
 const artifact=matching[0];
 if(artifact.expired||Date.parse(artifact.expires_at)<=Date.now())return {state:'expired-artifact'};
 if(!id(artifact.id)||!Number.isFinite(Date.parse(artifact.expires_at))||!Number.isSafeInteger(artifact.size_in_bytes)||artifact.size_in_bytes<=0||artifact.size_in_bytes>MAX_ARCHIVE||!/^sha256:[a-f0-9]{64}$/.test(artifact.digest||''))throw new Error('Invalid publication artifact inventory');
 return {state:'available',artifact,run:run.id};
 }
 return {state:'no-package-artifact'};
}

export async function retrieveArtifact(deployment,config,dependencies={}) {
 if(!config.artifactSource)return {state:'disabled'};
 const token=await githubToken(config),client=dependencies.client||githubClient(token);
 const selected=await findArtifact(deployment,client,config);if(selected.state!=='available')return selected;
 if(!token&&!dependencies.client)return {state:'credential-required'};
 if(!path.isAbsolute(config.artifactSource.python||''))throw new Error('Artifact extraction requires an absolute Python path');
 const staging=path.resolve(config.inbox,'..','artifact-downloads');await fs.mkdir(staging,{recursive:true});
 const root=await fs.mkdtemp(path.join(staging,'fetch-')),archive=path.join(root,'package.zip'),extracted=path.join(root,'package');
 try{
  await client.download(selected.artifact,archive);
  const extract=dependencies.extract||((input,output)=>execFileSync(config.artifactSource.python,['-I',fileURLToPath(new URL('./extract-artifact.py',import.meta.url)),input,output],{stdio:['ignore','pipe','pipe'],timeout:180000}));
  await extract(archive,extracted);
  const parsed=await (dependencies.readPackage||readPackage)(extracted);
  if(!await matchesDeployment(extracted,parsed.manifest,deployment,config))throw new Error('Downloaded package does not describe this deployment');
  const manifest=await fs.readFile(path.join(extracted,'manifest.json')),build=sha(manifest),destination=path.join(config.inbox,build);
  try{await fs.access(destination);const prior=await (dependencies.readPackage||readPackage)(destination);if(sha(await fs.readFile(path.join(destination,'manifest.json')))!==build||!await matchesDeployment(destination,prior.manifest,deployment,config))throw new Error('Existing inbox package differs');}
  catch(error){if(error.code!=='ENOENT')throw error;await fs.rename(extracted,destination);}
  return {state:'downloaded',run:selected.run,artifact:selected.artifact.id,directory:destination};
 }finally{
  // Remove only the unique directory created above, beneath the fixed staging root.
  if(path.dirname(root)!==staging||!path.basename(root).startsWith('fetch-'))throw new Error('Unsafe artifact cleanup target');
  await fs.rm(root,{recursive:true,force:true});
 }
}
