import contract from './contract.json' with { type: 'json' };
export function appearanceProfiles(record) {
 const result=[],seen=new Set();
 for(const pair of record.fields.render_profiles||[]){
  const profile=pair.key;if(typeof profile!=='string'||profile==='initial-south-first-frame'||!contract.renderProfiles[profile]||seen.has(profile)||!Array.isArray(pair.value))throw new Error('Invalid appearance profile');
  seen.add(profile);const metadata={};for(const entry of pair.value){if(!['file','source','state','scope'].includes(entry.key)||Object.hasOwn(metadata,entry.key)||typeof entry.value!=='string')throw new Error('Invalid appearance metadata');metadata[entry.key]=entry.value;}
  if(Object.keys(metadata).length!==4||!/^appearance-[a-f0-9]{32}\.png$/.test(metadata.file)||!metadata.scope.trim()||!metadata.source.trim())throw new Error('Incomplete appearance metadata');
  result.push({entity:record.id,filename:metadata.file,appearanceProfile:profile,source:metadata.source,state:metadata.state,scope:metadata.scope});
 }
 return result;
}
