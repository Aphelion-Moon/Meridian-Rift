import {promises as fs} from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {Mwn} from 'mwn';
import {readPackage} from './data-contract.js';
import {inspectPng} from './png.js';
import {readConfig,buildPlan,writeReport,publishPlan} from './autowiki.js';

export async function loadReviewedAssets(directory, sourceSha, publish = false) {
 const {manifest,records} = await readPackage(directory);
 if(manifest.source.commit!==sourceSha || manifest.source.repository!=='Aphelion-Moon/Meridian-Rift')throw new Error('Asset source differs from publication source');
 if(publish && (!manifest.publicationReady || manifest.provenance?.dirty!==false))throw new Error('Only a clean generation package can publish reviewed aliases');
 const aliases=JSON.parse(await fs.readFile(new URL('./reviewed-icon-aliases.json',import.meta.url),'utf8'));
 const entities=new Map(records.filter(r=>r.kind==='entity').map(r=>[r.id,r.fields]));
 const assets=new Map(manifest.icons.map(icon=>[icon.filename,icon])),images=[],seen=new Set();
 for(const alias of aliases){
  if(!/^[A-Z0-9][A-Za-z0-9_ -]*\.png$/.test(alias.filename)||seen.has(alias.filename.replaceAll('_',' ')))throw new Error('Invalid reviewed alias');
  seen.add(alias.filename.replaceAll('_',' '));
  const entity=entities.get(alias.entity);
  if(!entity?.icon_file||entity.icon_source!==alias.source||alias.appearanceProfile!=='initial-south-first-frame')throw new Error(`Reviewed appearance changed scope: ${alias.filename}`);
  const filename=path.resolve(directory,'icons',entity.icon_file),stat=await fs.lstat(filename);
  if(!stat.isFile()||stat.size>4*1024*1024)throw new Error('Invalid reviewed asset file');
  const bytes=await fs.readFile(filename);inspectPng(bytes);
  if(createHash('sha256').update(bytes).digest('hex')!==assets.get(entity.icon_file)?.sha256)throw new Error('Reviewed asset checksum mismatch');
  const escape=text=>String(text).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('[','&#91;').replaceAll(']','&#93;').replaceAll('{','&#123;').replaceAll('}','&#125;');
  const sourceUrl='https://github.com/'+manifest.source.repository+'/blob/'+sourceSha+'/'+entity.icon_source.split('/').map(encodeURIComponent).join('/');
  const provenance='<!-- Meridian asset provenance -->\n== Current Image ==\nCurrent Meridian Rift artwork for <code>'+escape(alias.entity)+'</code>, extracted from its default south-facing first frame. Runtime overlays and variants can differ.\n\nSource: ['+sourceUrl+' '+escape(entity.icon_source)+'], state <code>'+escape(entity.icon_state)+'</code>. Source revision: <code>'+sourceSha+'</code>.\n\nAttribution: Meridian Rift and upstream asset contributors. This reviewed source uses the repository’s default asset license, [https://creativecommons.org/licenses/by-sa/3.0/ CC BY-SA 3.0]. The wiki text license does not replace the image license.\n\n';
  images.push({title:'File:'+alias.filename,filename,sha1:createHash('sha1').update(bytes).digest('hex'),size:bytes.length,provenance});
 }
 return {pages:[],images};
}
export async function main(args=process.argv.slice(2),env=process.env){
 const publish=args.includes('--publish'),config=readConfig(env,publish),pos=args.filter(arg=>!['--publish','--dry-run'].includes(arg));
 if(pos.length!==2 || (publish&&args.includes('--dry-run')))throw new Error('Usage: reviewed-assets.js <package> <report-directory> --dry-run|--publish');
 const manifest=await loadReviewedAssets(pos[0],config.sourceSha,publish);
 const bot=new Mwn({apiUrl:config.apiUrl,silent:true,maxRetries:3,retryPause:5000,defaultParams:{maxlag:5,formatversion:2},...(publish?{username:env.USERNAME,password:env.PASSWORD}:{})});
 bot.setRequestOptions({timeout:30000,maxRedirects:0});if(publish)await bot.login();
 const plan=await buildPlan(bot,manifest,config);console.log(JSON.stringify(await writeReport(plan,pos[1])));if(publish)await publishPlan(bot,plan,pos[1]);
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href)main().catch(error=>{let message=error.code?'API error: '+error.code:error.message;for(const secret of [process.env.PASSWORD,process.env.USERNAME].filter(Boolean))message=message.replaceAll(secret,'[redacted]');console.error(message);process.exitCode=1});
