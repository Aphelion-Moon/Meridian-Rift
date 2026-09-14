import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {githubToken,githubClient,REPOSITORY} from './artifact-source.js';
import {builderCommit,builderRef,builderRunBranch,builderRequestKey,deploymentPlan,planDigest} from './source-binding.js';
const prefix='/repos/'+REPOSITORY,workflowName='autowiki-test-merges.yml';
const id=value=>Number.isSafeInteger(value)&&value>0;
const title=key=>'Autowiki source '+key;

/** One narrowly scoped mutation. An uncertain HTTP outcome must never be retried blindly. */
export async function dispatchBuild(token,input,request=fetch) {
 const ref=builderRef({testMergeBuilderRef:input.builder_ref});
 let response;
 try{response=await request('https://api.github.com'+prefix+'/actions/workflows/'+workflowName+'/dispatches',{method:'POST',headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2026-03-10','Content-Type':'application/json','User-Agent':'Meridian-Autowiki-Receiver'},body:JSON.stringify({ref:ref==='refs/heads/master'?'master':ref.slice('refs/tags/'.length),inputs:input}),redirect:'error',signal:AbortSignal.timeout(30000)});}
 catch{return {state:'uncertain'};}
 // A server error or broken response can follow an accepted request.
 if([400,401,403,404,422,429].includes(response.status)){await response.body?.cancel();return {state:'rejected',httpStatus:response.status};}
 if(response.status===204)return {state:'accepted'};
 if(response.status!==200){await response.body?.cancel();return {state:'uncertain'};}
 try{let size=0;const chunks=[];for await(const chunk of response.body){size+=chunk.length;if(size>8192)throw Error('Response limit');chunks.push(chunk);}const body=JSON.parse(Buffer.concat(chunks));return id(body.workflow_run_id)?{state:'accepted',runId:body.workflow_run_id}:{state:'uncertain'};}
 catch{return {state:'uncertain'};}
}

function trustedRun(run,pin,workflow,key,config) {
 return id(run.id)&&run.workflow_id===workflow&&run.head_sha===pin&&builderRunBranch(run,config)&&run.event==='workflow_dispatch'&&run.display_title===title(key)&&run.repository?.full_name===REPOSITORY&&run.head_repository?.full_name===REPOSITORY;
}
export async function approvedBuilderRef(client,config) {
 const ref=builderRef(config),pin=builderCommit(config),value=await client.json(prefix+'/git/ref/'+ref.slice('refs/'.length));
 if(value.ref!==ref)return false;
 let object=value.object;const seen=new Set();
 for(let depth=0;depth<5;depth++){
  if(!/^[a-f0-9]{40}$/.test(object?.sha||''))return false;
  if(object.type==='commit')return object.sha===pin;
  if(object.type!=='tag'||seen.has(object.sha))return false;seen.add(object.sha);
  const tag=await client.json(prefix+'/git/tags/'+object.sha);if(tag.sha!==object.sha)return false;object=tag.object;
 }
 return false;
}
function publicState(record) {
 return {state:record.state==='running'?'build-running':record.state==='completed'?(record.conclusion==='success'?'build-finished':'build-failed'):record.state==='rejected'?'build-request-rejected':record.state==='accepted'?'build-requested':'build-uncertain',...(id(record.runId)?{runId:record.runId}:{}),requestId:record.key};
}

/** Receiver-owned feature; persistent exclusive claim permits at most one automatic POST per plan/pin. */
export async function requestMissingBuild(deployment,config,dependencies={}) {
 const options=config.buildRequests;
 if(options?.enabled!==true||!(deployment.testMerges>0))return {state:'disabled'};
 if(!path.isAbsolute(options.directory||''))throw new Error('Build request journal must use an absolute directory');
 if(!config.testMergeBuilderCommit)return {state:'builder-update-required'};
 const pin=builderCommit(config),ref=builderRef(config),plan=deploymentPlan(deployment),key=builderRequestKey(deployment,config),filename=path.join(options.directory,key+'.json');
 const token=await githubToken({githubTokenFile:options.githubTokenFile});if(!token)return {state:'request-credential-required'};
 const client=dependencies.client||githubClient(token),dispatch=dependencies.dispatch||((input)=>dispatchBuild(token,input));
 const workflow=await client.json(prefix+'/actions/workflows/'+workflowName);
 if(!id(workflow.id)||workflow.path!=='.github/workflows/'+workflowName||workflow.state!=='active')return {state:'workflow-unavailable'};
 await fs.mkdir(options.directory,{recursive:true});
 let record;
 try{const stat=await fs.lstat(filename);if(!stat.isFile()||stat.size>65536)throw Error('Invalid request journal');record=JSON.parse(await fs.readFile(filename,'utf8'));if(record.version!==1||record.key!==key||record.builderCommit!==pin||(record.builderRef??'refs/heads/master')!==ref||planDigest(record.plan)!==planDigest(plan))throw Error('Request journal identity differs');}
 catch(error){if(error.code!=='ENOENT')throw error;}
 const save=async value=>{const temporary=filename+'.'+process.pid+'.pending',file=await fs.open(temporary,'w',0o600);try{await file.writeFile(JSON.stringify(value)+'\n');await file.sync();}finally{await file.close();}await fs.rename(temporary,filename);record=value;};
 // Even an uncertain request is reconciled against an actual run before considering its status.
 let run;
 if(id(record?.runId)){run=await client.json(prefix+'/actions/runs/'+record.runId);if(!trustedRun(run,pin,workflow.id,key,config))throw Error('Requested build run differs from its approved identity');}
 else{
  const started=record?Date.parse(record.createdAt):Date.now()-86400000;if(!Number.isFinite(started)||started>Date.now()+60000)throw Error('Invalid request creation time');
  const since=new Date(started-300000).toISOString();
  const result=await client.json(prefix+'/actions/workflows/'+workflow.id+'/runs?head_sha='+pin+(ref==='refs/heads/master'?'&branch=master':'')+'&event=workflow_dispatch&created='+encodeURIComponent('>='+since)+'&per_page=100');
  if(!Array.isArray(result.workflow_runs)||result.workflow_runs.length>100)throw Error('Invalid build request run inventory');
  const matches=result.workflow_runs.filter(r=>trustedRun(r,pin,workflow.id,key,config)).sort((a,b)=>b.id-a.id);
  if(matches.length)run=matches[0];
  // Bounded listing must not silently treat an unseen earlier request as absent.
  else if(result.total_count>100)return {state:'build-history-review-required'};
 }
 if(run){
  const state=run.status==='completed'?'completed':'running';
  if(!['queued','in_progress','waiting','requested','pending','completed'].includes(run.status))throw Error('Unsupported build run status');
  const conclusions=['success','failure','cancelled','timed_out','action_required','neutral','skipped','stale','startup_failure'];
  if(state==='completed'&&!conclusions.includes(run.conclusion))throw Error('Invalid completed build conclusion');
  await save({...record,version:1,key,builderCommit:pin,builderRef:ref,plan,createdAt:record?.createdAt||new Date().toISOString(),state,runId:run.id,conclusion:state==='completed'?run.conclusion:null,checkedAt:new Date().toISOString()});return publicState(record);
 }
 const retryRejected=record?.state==='rejected'&&dependencies.retryRejected===key;
 if(record&&!retryRejected)return publicState(record); // Includes a crash after claiming but before the POST.
 if(!await approvedBuilderRef(client,config))return {state:'builder-update-required'};
 const previousAttempts=retryRejected?[...(record.previousAttempts||[]),{createdAt:record.createdAt,state:record.state,httpStatus:record.httpStatus}]:[];
 if(previousAttempts.length>16)throw Error('Build request retry history needs an operations review');
 const claim={version:1,key,builderCommit:pin,builderRef:ref,plan,createdAt:new Date().toISOString(),state:'dispatching',previousAttempts};
 let file;
 if(retryRejected)await save(claim); // Explicit operator retry, under the receiver's existing lock.
 else{
 try{file=await fs.open(filename,'wx',0o600);}catch(error){if(error.code==='EEXIST')return {state:'build-uncertain',requestId:key};throw error;}
 // Persist the claim before sending. A second cycle or process cannot dispatch this plan again.
 try{await file.writeFile(JSON.stringify(claim)+'\n');await file.sync();}finally{await file.close();}
 }
 let result;try{result=await dispatch({source_plan:JSON.stringify(plan),builder_commit:pin,builder_ref:ref,request_id:key});}catch{result={state:'uncertain'};}
 if(!['accepted','uncertain','rejected'].includes(result?.state)||result.runId!==undefined&&!id(result.runId))result={state:'uncertain'};
 await save({...claim,state:result.state,...(id(result.runId)?{runId:result.runId}:{}),...([400,401,403,404,422,429].includes(result.httpStatus)?{httpStatus:result.httpStatus}:{})});return publicState(record);
}

if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 try{const [mode,filename,key]=process.argv.slice(2);if(mode!=='retry-rejected'||!/^[a-f0-9]{64}$/.test(key||''))throw Error('Usage: node build-request.js retry-rejected <private receiver config> <request ID>');const config=JSON.parse(await fs.readFile(filename,'utf8'));const {receive}=await import('./receiver.js');console.log(JSON.stringify(await receive(config,{requestBuild:(deployment,current)=>requestMissingBuild(deployment,current,{retryRejected:key})})));}
 catch{console.error('Build request recovery failed; inspect protected configuration and journal.');process.exitCode=1;}
}
