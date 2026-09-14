import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { validateDeployment } from './release.js';
const manifest={publicationReady:true,source:{commit:'a'.repeat(40)},provenance:{dirty:false,configurationInputs:[]},execution:{compiler:'516.1687',runtime:'516.1687'}};
const deployment={version:1,id:'fixture-1',commit:'a'.repeat(40),configurationDigest:createHash('sha256').update('[]').digest('hex'),compiler:'516.1687',runtime:'516.1687'};
test('deployment authority binds commit, configuration and runtime',()=>{
 assert.equal(validateDeployment(manifest,deployment),deployment);
 for(const changed of [{commit:'b'.repeat(40)},{configurationDigest:'0'.repeat(64)},{runtime:'516.1'}])assert.throws(()=>validateDeployment(manifest,{...deployment,...changed}));
 assert.throws(()=>validateDeployment({...manifest,provenance:{...manifest.provenance,dirty:true}},deployment));
});
test('deployment freshness and source-default scope are enforced',()=>{
 assert.throws(()=>validateDeployment(manifest,{...deployment,observedAt:'invalid'}),/expired/);
 assert.throws(()=>validateDeployment(manifest,{...deployment,observedAt:new Date(Date.now()-180000).toISOString()}),/expired/);
 assert.throws(()=>validateDeployment(manifest,{...deployment,configurationScope:'source-defaults'}),/runtime-configured/);
 assert.ok(validateDeployment({...manifest,profile:'source-defaults'},{...deployment,configurationScope:'source-defaults',observedAt:new Date().toISOString()}));
});
