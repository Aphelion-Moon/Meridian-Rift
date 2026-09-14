// Explicit version-one field types. Null is a real source value, not an omitted field.
import contract from './contract.json' with { type: 'json' };
export const FIELDS = contract.fields;
function checkValue(value, depth = 0) {
 if (depth > 14) throw new Error('Data nesting limit exceeded');
 if (value === null || typeof value === 'string') return;
 if (typeof value === 'number' && Number.isFinite(value)) return;
 if (Array.isArray(value)) {
  for (const pair of value) {
   if (!pair || Array.isArray(pair) || typeof pair !== 'object' || Object.keys(pair).sort().join(',') !== 'key,value') throw new Error('Invalid DM list entry');
   checkValue(pair.key, depth + 1); checkValue(pair.value, depth + 1);
  }
  return;
 }
 throw new Error('Unsupported data value');
}
export function validateFields(kind, fields) {
 const optionalEntity = new Set(contract.optionalEntity);
 for (const field of Object.keys(FIELDS[kind])) {
  if ((kind === 'entity' && optionalEntity.has(field)) || contract.optionalFields?.[kind]?.includes(field)) continue;
  if (!(field in fields)) throw new Error(`Missing ${kind}.${field}`);
 }
 for (const [field, value] of Object.entries(fields)) {
  const type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
  if (!FIELDS[kind]?.[field]?.includes(type)) throw new Error(`Unknown or invalid field ${kind}.${field}`);
  checkValue(value);
 }
 for (const {key} of fields.dynamic_fields || []) if (typeof key !== 'string' || !FIELDS[kind][key] || fields[key] !== null) throw new Error('Variable fields must be known and have no sampled fixed value');
 if (kind === 'reaction') {
  const dynamic = new Set((fields.dynamic_fields || []).map(pair => pair.key));
  for (const field of dynamic) if (!Object.hasOwn(FIELDS.reaction, field) || fields[field] !== null) throw new Error('Invalid dynamic reaction field');
  for (const field of ['required_temp','optimal_temp','overheat_temp','is_cold_recipe','optimal_ph_min','optimal_ph_max','purity_min','required_reagents','required_catalysts']) {
   if (fields[field] === null && !dynamic.has(field)) throw new Error(`Unexplained null reaction field: ${field}`);
  }
 }
}

export function relationshipKind(target, identity) { return target === 'auto' ? Object.entries(contract.identityPrefixes).find(([prefix])=>identity === prefix || identity.startsWith(prefix+'/'))?.[1] || 'entity' : target; }
