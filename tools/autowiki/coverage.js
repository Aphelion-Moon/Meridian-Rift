import fs from 'node:fs';
import contract from './contract.json' with { type:'json' };
import { relationshipKind } from './fields.js';
import {readPackage} from './data-contract.js';
const [directory,output] = process.argv.slice(2);
if (!directory || !output || fs.existsSync(output)) throw new Error('Usage: coverage.js <package> <new-output.json>');
const {records,manifest} = await readPackage(directory);
const sets = new Map(manifest.datasets.map(dataset=>[dataset.kind,new Set(records.filter(record=>record.kind===dataset.kind).map(record=>record.id))]));
const fields = contract.relations;
const outside = [],counts={resolved:0,outside:0,otherDomain:0};
for (const record of records) for (const [field,target] of Object.entries(fields[record.kind]||{})) {
 const value=record.fields[field], ids=Array.isArray(value)?value.map(pair=>pair.key):value?[value]:[];
 for(const id of ids){const kind=typeof id==='string'?relationshipKind(target,id):null;
  if(!kind){counts.otherDomain++;continue}if(sets.get(kind)?.has(id)){counts.resolved++;continue}counts.outside++;outside.push({fromKind:record.kind,from:record.id,field,toKind:kind,to:id});
 }
}
const report={source:manifest.source,counts,missingInitialIcons:manifest.unresolvedIcons.length,dynamicReactions:records.filter(record=>record.kind==='reaction'&&record.fields.dynamic_fields?.length).map(record=>record.id),referencesOutsideExport:outside,interpretation:'Outside references are coverage gaps, not automatically broken game references. Abstract parents and intentionally unpublished nodes need explicit treatment by consumers.'};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...counts,dynamicReactions:report.dynamicReactions.length}));
