import fs from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

/** Read-only TGS client. Authentication is the only POST; tokens stay in memory. */
export class TgsClient {
 constructor(config, fetcher = fetch) {
  const url = new URL(config.url);
  if (url.username || url.password || url.search || url.hash || !['http:', 'https:'].includes(url.protocol)) throw new Error('Invalid TGS API address');
  if (url.protocol !== 'https:' && !['127.0.0.1', '[::1]'].includes(url.hostname)) throw new Error('TGS credentials require HTTPS outside loopback');
  this.base = url.href.replace(/\/$/, '');this.config=config;this.fetcher=fetcher;
 }
 async request(route, method='GET', extra={}) {
  let response;
  try { response=await this.fetcher(this.base+route,{method,redirect:'error',signal:AbortSignal.timeout(15000),headers:{Accept:'application/json','Content-Type':'application/json','User-Agent':'MeridianAutowiki/0.2',Api:'Tgstation.Server.Api/10.14.1',...(this.token?{Authorization:'Bearer '+this.token}:{}),...extra}}); }
  catch { throw new Error('TGS connection failed; no deployment evidence was issued'); }
  if (!response.ok) throw new Error(`TGS ${route || 'authentication'} returned HTTP ${response.status}`);
  try { return await response.json(); } catch { throw new Error('TGS returned invalid JSON'); }
 }
 async login() {
  const text=await fs.readFile(this.config.credentialsFile,'utf8');const credentials={};
  for (const line of text.replace(/^\uFEFF/,'').split(/\r?\n/)) {const match=line.match(/^\s*(username|password)\s*:(.*)$/i);if(match)credentials[match[1].toLowerCase()]=match[2].trim();}
  if(!credentials.username||!credentials.password)throw new Error('TGS credential file needs username and password labels');
  const token=await this.request('','POST',{Authorization:'Basic '+Buffer.from(credentials.username+':'+credentials.password).toString('base64')});
  if(typeof token.bearer!=='string'||!token.bearer)throw new Error('TGS did not provide an authentication token');this.token=token.bearer;
 }
 async instance() {
  if(this.config.instanceId!==undefined){if(!Number.isSafeInteger(this.config.instanceId)||this.config.instanceId<=0)throw new Error('Invalid TGS instance ID');return this.config.instanceId;}
  if(!this.config.instanceName)throw new Error('Select the TGS instance by exact name or numeric ID');
  const matches=[];
  for(let page=1;page<=100;page++){
   const result=await this.request('/Instance/List?page='+page+'&pageSize=100');if(!Array.isArray(result.content))throw new Error('Invalid TGS instance list');
   matches.push(...result.content.filter(row=>row.name===this.config.instanceName));
   if(result.content.length<100){if(matches.length!==1)throw new Error('TGS instance name is missing or ambiguous');return matches[0].id;}
  }
  throw new Error('TGS instance listing exceeded its bounded limit');
 }
 async active() {
  if(!this.token)await this.login();const instanceId=await this.instance();
  const response=await this.request('/DreamDaemon','GET',{Instance:String(instanceId)});
  return activeBuild(response,instanceId);
 }
}

/** Deliberately select the running job, never the pending compile or repository HEAD. */
export function activeBuild(response,instanceId) {
 const job=response.activeCompileJob;
 if(response.status!==2&&response.status!=='Online')throw new Error('TGS game is not online');
 if(!job||!Number.isSafeInteger(job.id)||job.id<=0)throw new Error('TGS active build is unavailable; check ReadRevision permission');
 const revision=job.revisionInformation,commit=revision?.commitSha;
 if(!/^[a-f0-9]{40}$/.test(commit||''))throw new Error('Active build has no exact Git commit');
 const engine=job.engineVersion;
 if(!engine||![0,'Byond'].includes(engine.engine)||!/^\d+\.\d+(?:\.0){0,2}$/.test(engine.version||''))throw new Error('Active BYOND identity is unsupported');
 if(!/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/i.test(job.directoryName||''))throw new Error('Active build directory is unavailable');
 const originCommit=revision.originCommitSha??null;
 if(originCommit!==null&&!/^[a-f0-9]{40}$/.test(originCommit))throw new Error('Invalid TGS origin commit');
 let mergeIdentities=null;
 if(Array.isArray(revision.activeTestMerges)){
  if(revision.activeTestMerges.length>128)throw new Error('TGS merge inventory exceeds its limit');
  const numbers=new Set();
  mergeIdentities=revision.activeTestMerges.map(m=>{
   if(!Number.isSafeInteger(m.number)||m.number<=0||!Number.isSafeInteger(m.id)||m.id<=0||!Number.isFinite(Date.parse(m.mergedAt))||!/^[a-f0-9]{40}$/.test(m.targetCommitSha||'')||numbers.has(m.number))throw new Error('Incomplete or ambiguous TGS merge identity');
   numbers.add(m.number);return {number:m.number,commit:m.targetCommitSha,mergedAt:m.mergedAt,id:m.id};
  }).sort((a,b)=>Date.parse(a.mergedAt)-Date.parse(b.mergedAt)||a.id-b.id);
 }
 return {version:1,instanceId,compileJobId:job.id,commit,originCommit,mergeIdentities,byond:engine.version.split('.').slice(0,2).join('.'),directory:job.directoryName,testMerges:mergeIdentities?.length??null,repositoryOrigin:job.repositoryOrigin??null};
}

/** An observation is not a publication receipt: build-time configuration still needs proof. */
export async function observe(config,fetcher) {
 const client=new TgsClient(config,fetcher);const before=await client.active();
 const gameRoot=await fs.realpath(path.join(config.instancePath,'Game'));
 const live=await fs.realpath(path.join(gameRoot,'Live'));
 const expected=await fs.realpath(path.join(gameRoot,before.directory));
 const relative=path.relative(expected,live);
 if(relative.startsWith('..')||path.isAbsolute(relative))throw new Error('Local Live directory differs from the TGS active build');
 const after=await client.active();if(JSON.stringify(before)!==JSON.stringify(after))throw new Error('TGS changed builds during observation');
 return {...before,observedAt:new Date().toISOString(),liveDirectory:live,publicationReady:false,reason:'Requires attested package and independently captured build-time configuration'};
}

/** Independently reconstruct source-default inputs from TGS's exact Git object. */
export async function sourceDeployment(config,fetcher,run=execFileSync) {
 if(!path.isAbsolute(config.repository||''))throw new Error('TGS source repository must be an absolute local path');
 const observation=await observe(config,fetcher);
 const git=args=>run(config.git||'git',['-C',config.repository,...args],{stdio:['ignore','pipe','pipe'],maxBuffer:64*1024*1024,timeout:15000});
 const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
 const sourceTree=git(['rev-parse','--verify',observation.commit+'^{tree}']).toString('utf8').trim();
 if(!/^[a-f0-9]{40}$/.test(sourceTree))throw new Error('Active source tree is unavailable');
 const files=git(['ls-tree','-r','--name-only','-z',observation.commit,'--','config/']).toString('utf8').split('\0').filter(name=>/\.(txt|json|toml)$/i.test(name));
 files.sort();
 const inputs=files.map(name=>({name,sha256:hash(git(['show',observation.commit+':'+name]))}));
 const after=await observe(config,fetcher);
 if(after.commit!==observation.commit||after.compileJobId!==observation.compileJobId||after.byond!==observation.byond||after.originCommit!==observation.originCommit||JSON.stringify(after.mergeIdentities)!==JSON.stringify(observation.mergeIdentities))throw new Error('TGS changed while source evidence was collected');
 return {version:1,id:`tgs-${observation.instanceId}-${observation.compileJobId}`,commit:observation.commit,sourceTree,originCommit:observation.originCommit,mergeIdentities:observation.mergeIdentities,compiler:observation.byond,runtime:observation.byond,configurationDigest:hash(JSON.stringify(inputs)),configurationScope:'source-defaults',observedAt:after.observedAt,testMerges:observation.testMerges};
}

if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 try{const filename=process.argv[2];if(!filename)throw new Error('Usage: node tgs.js <private TGS configuration.json>');console.log(JSON.stringify(await observe(JSON.parse(await fs.readFile(filename,'utf8')))));}
 catch(error){console.error(error.code?'TGS observation failed; check the private configuration and local paths.':error.message);process.exitCode=1;}
}
