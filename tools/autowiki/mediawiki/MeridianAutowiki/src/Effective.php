<?php
namespace Meridian\Autowiki;

/** Human values are an explicit overlay. Raw exported fields remain immutable. */
final class Effective {
 public static function record(array $record, array $decisions): array {
  $result = $record;
  $result['annotations'] = [];
  $result['editorial'] = [];
  $result['conflicts'] = [];
  $family=$record['fields']['documentation_family']??null;
  if(is_string($family)&&preg_match('/^[a-z0-9][a-z0-9._-]{0,159}$/',$family))$result['family']=Package::key($record['kind'],'family:'.$family);
  $slots = [];
  foreach ($decisions as $row) {
   $d = $row['decision'];
   if ($d['type'] === 'preserve') continue; // The public-source resolver owns preservation.
   if ($d['state'] !== 'active') continue;
   if (!Decisions::applicable($d, $record)) { $result['conflicts'][] = $row['page']; continue; }
   if ($d['type'] === 'annotation') { $result['annotations'][] = $d['value']; continue; }
   if (!in_array($d['type'], ['alias', 'correction', 'family', 'match'], true)) continue;
   $slot = $d['type'].':'.implode(',', $d['watch']);
   $slots[$slot][] = $row;
  }
  foreach ($slots as $rows) {
   if (count(array_unique(array_column(array_column($rows, 'decision'), 'value'))) > 1) {
    foreach ($rows as $row) $result['conflicts'][] = $row['page'];
    continue;
   }
   $row = end($rows); $d = $row['decision'];
   if ($d['type'] === 'alias') $result['name'] = $d['value'];
   elseif ($d['type'] === 'correction') {
    $field = $d['watch'][0];
    try { $value = json_decode($d['value'], true, 32, JSON_THROW_ON_ERROR); }
    catch (\JsonException) { $result['conflicts'][] = $row['page']; continue; }
    $fields = $record['fields']; $fields[$field] = $value;
    try { Package::validateFields($record['kind'], $fields); }
    catch (\RuntimeException) { $result['conflicts'][] = $row['page']; continue; }
    $result['fields'][$field] = $value;
    $result['editorial'][$field] = ['page'=>$row['page'], 'revision'=>$row['revision'], 'reason'=>$d['reason']];
   } else $result[$d['type']] = $d['value'];
  }
  return $result;
 }
}
