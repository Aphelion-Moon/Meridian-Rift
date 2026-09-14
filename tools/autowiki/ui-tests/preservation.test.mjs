import { JSDOM, VirtualConsole } from 'jsdom';
import fs from 'node:fs';
import { webcrypto } from 'node:crypto';
import assert from 'node:assert/strict';

const errors=[], logs=new VirtualConsole();logs.on('jsdomError',e=>errors.push(e.message));logs.on('error',e=>errors.push(String(e)));
const dom=new JSDOM('<div id="maw-dashboard"></div>',{url:'https://meridian-wiki.a13.info/wiki/Special:Autowiki',runScripts:'outside-only',virtualConsole:logs}),w=dom.window;
for(const name of ['window','document','navigator','Element','HTMLElement','SVGElement','Node','MutationObserver'])Object.defineProperty(globalThis,name,{value:w[name],configurable:true});
Object.defineProperty(w.crypto,'subtle',{value:webcrypto.subtle});w.TextEncoder=TextEncoder;
const Vue=await import('vue'),Codex=await import('@wikimedia/codex');
const build='a'.repeat(64),old='b'.repeat(64),key='c'.repeat(64),pub='d'.repeat(64),blocked='e'.repeat(64),fingerprint='f'.repeat(64),other='1'.repeat(64);
const record={key,build,kind:'entity',id:'/obj/item/wrench',name:'Wrench',fields:{name:'Wrench',force:99}},saves=[],reads=[];
let row=null,missing=false,hold=null,resolveHold=null,saveHold=null,resolveSave=null;
const choice=id=>({id,build:id===pub?old:other,published:'20260914000000',sourceBuild:old});
const result=id=>id===pub?{eligible:true,fingerprint,current:missing?null:record,retained:{...record,build:old,fields:{name:'Wrench',force:5}},publication:{...choice(id),sourceBuild:old}}:{eligible:false,message:'Current visibility prevents preservation.'};
w.mw={util:{getUrl:(title,params={})=>'/wiki/'+encodeURIComponent(title)+'?'+new URLSearchParams(params)},loader:{using:()=>Promise.resolve(name=>name==='vue'?Vue:Codex)},Api:class{
 async get(p){reads.push(p);let data;
  if(p.view==='status')data={active:'',builds:[{id:build,counts:{entity:1},source:'1'.repeat(40)}],outbox:[]};
  else if(p.view==='preservation')data=p.publication?(p.publication===pub&&hold?await hold:result(p.publication)):{rows:p.offset?[choice(pub)]:[choice(pub),choice(blocked)],more:!p.offset};
  else if(p.view==='decisions')data={rows:row?[row]:[],more:false};
  else if(p.key)data=missing?{missing:true,historical:{...record,build:old},decisions:row?[row]:[]}:{record,effective:{...record,conflicts:[]},decisions:row?[row]:[],images:[],units:{},related:[],guides:[]};
  else data={rows:[record],more:false};return {autowikidata:data};
 }
 async postWithToken(token,p){saves.push(p);if(saveHold)await saveHold;row={page:5,revision:(row?.revision||40)+1,title:'Autowiki Decision:'+p.key,applicable:true,decision:JSON.parse(p.payload)};return {autowikidecision:{revision:row.revision}};}
}};
const tick=()=>new Promise(resolve=>setTimeout(resolve,35));let checks=0;
const check=(ok,label)=>{assert.ok(ok,label);checks++;};
const button=label=>[...w.document.querySelectorAll('button')].find(e=>e.textContent===label);
const click=label=>{assert.ok(button(label),'Missing button '+label);button(label).click();};
const submit=()=>w.document.querySelector('.maw-preservation-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));
const publicationLabel=id=>choice(id).build.slice(0,12)+' · 20260914000000';
w.eval(fs.readFileSync(new URL('../mediawiki/MeridianAutowiki/resources/dashboard.js',import.meta.url),'utf8'));await tick();await tick();click('Wrench');await tick();click('Preserve Published Data');await tick();
check(button('Save Reviewed Preservation').disabled,'Cannot save without viewing evidence');
click('Preserve Published Data');await tick();check(w.document.querySelectorAll('.maw-preservation-form').length===1,'Repeated opening keeps a single editor');
click('More Publications');await tick();check(reads.at(-1).offset===50,'Publication history uses bounded pagination');click('Earlier Publication Page');await tick();
hold=new Promise(resolve=>resolveHold=resolve);click(publicationLabel(pub));click(publicationLabel(blocked));await tick();resolveHold(result(pub));await tick();hold=null;
check(button('Save Reviewed Preservation').disabled&&w.document.body.textContent.includes('Current visibility prevents preservation.'),'A late allowed response cannot replace a newer blocked choice');
click(publicationLabel(pub));await tick();check(!button('Save Reviewed Preservation').disabled,'An eligible comparison enables review');
check(w.document.body.textContent.includes('Changed Field')&&w.document.body.textContent.includes('99')&&w.document.body.textContent.includes('5'),'Changed current and published values appear side by side');
w.document.querySelector('[aria-label="Preservation reason"]').value='Keep the verified behavior while the new export is investigated.';
saveHold=new Promise(resolve=>resolveSave=resolve);submit();submit();await tick();check(saves.length===1,'Repeated submission does not create competing requests');resolveSave();saveHold=null;await tick();await tick();
let saved=saves.at(-1),payload=JSON.parse(saved.payload);
check(saved.base===0&&saved.build===build,'New preservation is tied to the selected replacement build');
check(payload.fingerprint===fingerprint&&JSON.parse(payload.value).publication===pub&&JSON.parse(payload.value).forBuild===build,'Submission carries exactly the reviewed publication and fingerprint');
click('Preserve Published Data');await tick();check(button('Save Reviewed Preservation').disabled&&w.document.body.textContent.includes('already has a preservation decision'),'Existing choices require explicit review before editing');
click('Editorial Decisions');await tick();
// Open through the decision row, independently of the current catalogue build.
click('preserve');await tick();
click('Review Preservation');await tick();click(publicationLabel(pub));await tick();submit();await tick();await tick();check(saves.at(-1).base===41,'Editing sends the actual reviewed native revision');
missing=true;click('Review Preservation');await tick();click(publicationLabel(pub));await tick();check(w.document.body.textContent.includes('absent from the replacement'),'A missing replacement still presents the retained source');
// Return to the source record, where a missing source still exposes revocation.
submit();await tick();await tick();const reason=w.document.querySelector('[aria-label="Reason to revoke preservation"]');check(Boolean(reason),'Missing source does not remove revocation controls');
reason.value='The old behavior should no longer be retained.';reason.closest('form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await tick();await tick();
payload=JSON.parse(saves.at(-1).payload);check(payload.state==='revoked'&&payload.fingerprint===fingerprint&&saves.at(-1).base===43,'Revocation retains original evidence and revision guard');
check(errors.length===0,errors.join('\n'));
console.log(`PASS ${checks} preservation dashboard assertions (fixture API, actual Vue/Codex DOM).`);dom.window.close();
