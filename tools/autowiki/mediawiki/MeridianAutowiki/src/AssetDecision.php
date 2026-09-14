<?php
namespace Meridian\Autowiki;

use RuntimeException;
final class AssetDecision {
 public static function value(string $value):array {
  $v=json_decode($value,true,32,JSON_THROW_ON_ERROR);
  if(!is_array($v)||array_diff(array_keys($v),['entity','filename','expectedImageHash','profile'])||!in_array(count($v),[3,4],true)||!preg_match('/^[a-f0-9]{64}$/',$v['entity']??'')||!preg_match('/^[a-z0-9]{1,40}$/',$v['expectedImageHash']??''))throw new RuntimeException('Invalid reviewed image mapping');
  if(isset($v['profile'])&&!isset(Package::contract()['renderProfiles'][$v['profile']]))throw new RuntimeException('Unknown image profile');
  $title=\MediaWiki\Title\Title::makeTitleSafe(NS_FILE,$v['filename']);
  if(!$title||$title->getDBkey()!==$v['filename'])throw new RuntimeException('Invalid reviewed image title');
  return $v;
 }
 public static function prepare(Store $store,array $d,string $build,array $issue):array {
  if($issue['rule']!=='legacy-image')throw new RuntimeException('Select an image reconciliation issue');
  $v=self::value($d['value']);
  if($v['filename']!==$issue['observation']['filename']||$v['expectedImageHash']!==$issue['observation']['image_hash'])throw new RuntimeException('Image evidence changed; reload the comparison');
  $r=$store->record($build,$v['entity']);if(!$r||$r['kind']!=='entity'||!Assets::get($build,$r['key'],$v['profile']??'initial-south-first-frame'))throw new RuntimeException('Candidate has no validated image');
  $initial=($v['profile']??'initial-south-first-frame')==='initial-south-first-frame';
  $d['watch']=$initial?['icon_source','icon_state','appearance_scope']:['selected_profile'];
  $fields=$initial?$r['fields']:['selected_profile'=>self::profileEvidence($r['fields'],$v['profile'])];
  $d['fingerprint']=Package::fingerprint($fields,$d['watch']);return $d;
 }
 public static function profileEvidence(array $fields,string $profile):?array {
  foreach($fields['render_profiles']??[] as $entry)if(($entry['key']??null)===$profile){$value=[];foreach($entry['value'] as $pair)$value[$pair['key']]=$pair['value'];return ['profile'=>$profile,'metadata'=>$value];}
  return null;
 }
}
