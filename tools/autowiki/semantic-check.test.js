import test from 'node:test';
import assert from 'node:assert/strict';
import {gate,inspect} from './semantic-check.js';
const record=(id,fields={})=>({kind:'entity',id,fields});

test('machine construction accepts positive item quantities and keeps legacy entities compatible',()=>{
 const parts=[record('/obj/item/part')];
 const board=record('/obj/item/board',{construction_components:[{key:'/obj/item/part',value:5}],construction_alternatives:[],stock_part_tier:4,stock_part_energy_rating:10,construction_needs_anchored:1,construction_specific_parts:0});
 assert.deepEqual(inspect([...parts,board,record('/obj/item/legacy')]),[]);
 for(const value of [0,-1,1.5,'2']) {
  const broken=structuredClone(board);broken.fields.construction_components[0].value=value;
  assert.ok(inspect([...parts,broken]).some(i=>i.rule==='invalid-construction-quantity'));
 }
 const duplicate=structuredClone(board);duplicate.fields.construction_components.push({...duplicate.fields.construction_components[0]});
 assert.ok(inspect([...parts,duplicate]).some(i=>i.rule==='duplicate-construction-component'));
 for(const [field,value,rule] of [['stock_part_tier',0,'invalid-stock-part-tier'],['stock_part_tier',1.5,'invalid-stock-part-tier'],['stock_part_energy_rating',0,'invalid-stock-part-energy-rating'],['construction_needs_anchored',2,'invalid-construction-flag']]) {
  assert.ok(inspect([record('/obj/item/invalid',{[field]:value})]).some(i=>i.rule===rule));
 }
 assert.ok(inspect([record('/obj/item/invalid',{construction_alternatives:[{key:'metal',value:1}]})]).some(i=>i.rule==='invalid-construction-component'));
});

test('a new unresolved construction requirement blocks an established publication',()=>{
 const previous={records:[record('/obj/item/board')],counts:{entity:1}};
 const current={records:[record('/obj/item/board',{construction_components:[{key:'/obj/item/missing',value:1}]})],counts:{entity:1}};
 assert.equal(gate(previous,current).ok,false);
 assert.ok(gate(previous,current).reasons.some(i=>i.rule==='outside-export'&&i.field==='construction_components'));
});
test('semantic gate detects canonical collisions and unexplained losses',()=>{
 const old={records:[record('/a'),record('/b')],counts:{entity:2}};
 const next={records:[record('/a')],counts:{entity:1}};
 assert.equal(gate(old,next).ok,false);
 assert.ok(gate(old,next).reasons.some(r=>r.rule==='removed-identities'));
 assert.ok(inspect([record('/a',{documentation_id:'tool'}),record('/b',{documentation_id:'tool'})]).some(r=>r.rule==='duplicate-canonical-id'));
});
test('baseline debt stays visible without reopening; a new broken edge fails the gate',()=>{
 const old={records:[{kind:'design',id:'/design/a',fields:{build_path:'/unexported'}}],counts:{design:1}};
 const baseline=inspect(old.records);
 assert.equal(gate(old,old,baseline).ok,true);
 const next={...old,records:[...old.records,{kind:'design',id:'/design/b',fields:{build_path:'/new-missing'}}]};
 assert.equal(gate(old,next,baseline).ok,false);
 assert.ok(gate(old,old,baseline).issues.length);
});
