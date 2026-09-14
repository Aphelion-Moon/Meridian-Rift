<?php
namespace Meridian\Autowiki;
use RuntimeException;
/** Validates external data before it reaches a database or renderer. No executable package inputs. */
final class Package {
 public static function contract(): array { static $contract;return $contract??=json_decode(file_get_contents(__DIR__.'/../contract.json'),true,512,JSON_THROW_ON_ERROR); }
 public static function profiles(array $r):array {
  $profiles=[];foreach($r['fields']['render_profiles']??[] as $pair){$profile=$pair['key'];if(!is_string($profile)||$profile==='initial-south-first-frame'||!isset(self::contract()['renderProfiles'][$profile])||isset($profiles[$profile])||!is_array($pair['value']))throw new RuntimeException('Invalid render profile');
   $metadata=[];foreach($pair['value'] as $entry){if(!in_array($entry['key'],['file','source','state','scope'],true)||isset($metadata[$entry['key']])||!is_string($entry['value']))throw new RuntimeException('Invalid profile metadata');$metadata[$entry['key']]=$entry['value'];}
   if(count($metadata)!==4||!preg_match('/^appearance-[a-f0-9]{32}\.png$/',$metadata['file']??'')||!trim($metadata['source']??'')||!trim($metadata['scope']??''))throw new RuntimeException('Incomplete profile metadata');
   $profiles[$profile]=['entity'=>$r['id'],'filename'=>$metadata['file'],'appearanceProfile'=>$profile,'source'=>$metadata['source'],'state'=>$metadata['state'],'scope'=>$metadata['scope']];
  }return $profiles;
 }
 public static function key(string $kind,string $identity): string { return hash('sha256',$kind.':'.$identity); }
 public static function relationshipKind(string $target,string $identity):string {
  if($target!=='auto')return $target;foreach(self::contract()['identityPrefixes'] as $prefix=>$kind)if($identity===$prefix||str_starts_with($identity,$prefix.'/'))return $kind;return 'entity';
 }
 public static function recordKey(array $r):string {
  $id=$r['fields']['documentation_id']??null;
  if($id!==null&&!preg_match('/^[a-z0-9][a-z0-9._\/-]{0,159}$/',$id))throw new RuntimeException('Invalid stable documentation identity');
  return self::key($r['kind'],$id===null?$r['id']:'canonical:'.$id);
 }
 public static function canonical(mixed $value): mixed {
  if(!is_array($value))return $value;
  if(!array_is_list($value))ksort($value);
  return array_map([self::class,'canonical'],$value);
 }
 public static function fingerprint(array $fields,array $names): string {
  $picked=[];sort($names);foreach($names as $name)$picked[$name]=['present'=>array_key_exists($name,$fields),'value'=>$fields[$name]??null];
  return hash('sha256',json_encode(self::canonical($picked),JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR));
 }
 private static function read(string $root,string $relative,int $limit): string {
  $file=realpath($root.DIRECTORY_SEPARATOR.$relative);
  if(!$file||!str_starts_with($file,$root.DIRECTORY_SEPARATOR)||!is_file($file)||filesize($file)>$limit)throw new RuntimeException('Invalid package file');
  return file_get_contents($file);
 }
 public static function validateFields(string $kind,array $fields): void {
  $contract=self::contract();$schema=$contract['fields'][$kind]??null;
  if(!$schema)throw new RuntimeException('Unknown record kind');
  foreach($schema as $name=>$types)if(!array_key_exists($name,$fields)&&!($kind==='entity'&&in_array($name,$contract['optionalEntity'],true))&&!in_array($name,$contract['optionalFields'][$kind]??[],true))throw new RuntimeException('Missing field '.$kind.'.'.$name);
  foreach($fields as $name=>$value){$type=match(true){$value===null=>'null',is_array($value)=>'array',is_string($value)=>'string',is_int($value)||is_float($value)=>'number',default=>'invalid'};if(!in_array($type,$schema[$name]??[],true))throw new RuntimeException('Invalid field '.$kind.'.'.$name);self::listValue($value);}
  foreach($fields['dynamic_fields']??[] as $pair)if(!is_string($pair['key'])||!isset($schema[$pair['key']])||($fields[$pair['key']]??null)!==null)throw new RuntimeException('Variable fields must be known and have no sampled fixed value');
  if($kind==='entity')self::profiles(['id'=>'','fields'=>$fields]);
  if($kind==='reaction'){
   $dynamic=array_column($fields['dynamic_fields']??[],'key');
   foreach($dynamic as $name)if(!isset($schema[$name])||$fields[$name]!==null)throw new RuntimeException('Invalid dynamic field');
   foreach(['required_temp','optimal_temp','overheat_temp','is_cold_recipe','optimal_ph_min','optimal_ph_max','purity_min','required_reagents','required_catalysts'] as $name)if($fields[$name]===null&&!in_array($name,$dynamic,true))throw new RuntimeException('Unexplained variable recipe');
  }
 }
 private static function listValue(mixed $value,int $depth=0):void {
  if($depth>14)throw new RuntimeException('Nested value too deep');
  if(is_array($value)){if(!array_is_list($value))throw new RuntimeException('Expected DM list');foreach($value as $pair){if(!is_array($pair)||count($pair)!==2||!array_key_exists('key',$pair)||!array_key_exists('value',$pair))throw new RuntimeException('Malformed DM list');self::listValue($pair['key'],$depth+1);self::listValue($pair['value'],$depth+1);}}
  elseif($value!==null&&!is_string($value)&&!is_int($value)&&!(is_float($value)&&is_finite($value)))throw new RuntimeException('Unsupported value');
 }
 public static function load(string $directory):array {
  $root=realpath($directory);if(!$root)throw new RuntimeException('Package not found');
  $raw=self::read($root,'manifest.json',64*1024*1024);$m=json_decode($raw,true,512,JSON_THROW_ON_ERROR);
  if(!in_array($m['schemaVersion']??null,[1,2],true)||($m['profile']??'')!=='source-defaults'||($m['source']['repository']??'')!=='Aphelion-Moon/Meridian-Rift'||!preg_match('/^[a-f0-9]{40}$/',$m['source']['commit']??''))throw new RuntimeException('Incompatible manifest');
  $contract=self::contract();$records=[];$seen=[];$bytes=0;
  foreach($m['datasets']??[] as $d){$kind=$d['kind'];if(!isset($contract['fields'][$kind])||isset($seen[$kind])||$d['filename']!==$kind.'.jsonl')throw new RuntimeException('Invalid dataset');$seen[$kind]=true;
   $text=self::read($root,$d['filename'],64*1024*1024);$bytes+=strlen($text);if($bytes>256*1024*1024||strlen($text)!==$d['bytes']||hash('sha256',$text)!==$d['sha256'])throw new RuntimeException('Dataset integrity failure');$count=0;
   foreach(explode("\n",trim($text)) as $line){$r=json_decode($line,true,64,JSON_THROW_ON_ERROR);if($r['kind']!==$kind||!is_string($r['id'])||strlen($r['id'])>1024||!str_starts_with($r['id'],'/')||preg_match('/[\x00-\x1f]/',$r['id']))throw new RuntimeException('Invalid record identity');$key=self::recordKey($r);if(isset($records[$key]))throw new RuntimeException('Duplicate record');self::validateFields($kind,$r['fields']);$records[$key]=$r;$count++;}
   if(!$count||$count!==$d['count'])throw new RuntimeException('Incorrect record count');
  }
  if(count($seen)!==count($m['schemaVersion']===1?$contract['legacyDatasets']:$contract['fields']))throw new RuntimeException('Incomplete export');
  $icons=[];$entities=[];$profiles=[];foreach($records as $r)if($r['kind']==='entity'){$entities[$r['id']]=$r;foreach(self::profiles($r) as $profile){if(isset($profiles[$profile['filename']]))throw new RuntimeException('Duplicate profile filename');$profiles[$profile['filename']]=$profile;}}
  foreach($m['icons']??[] as $icon){$name=$icon['filename'];$record=$entities[$icon['entity']]??null;if(isset($icons[$name]))throw new RuntimeException('Duplicate image identity');
   if(isset($profiles[$name])){foreach(['entity','appearanceProfile','source','state','scope'] as $field)if(($icon[$field]??null)!==$profiles[$name][$field])throw new RuntimeException('Profile asset differs from its record');}
   elseif(!preg_match('/^entity-[a-f0-9]{32}\.png$/',$name)||($record['fields']['icon_file']??null)!==$name||($icon['appearanceProfile']??'')!=='initial-south-first-frame')throw new RuntimeException('Invalid image identity');
   $png=self::read($root,'icons/'.$name,4*1024*1024);if(strlen($png)!==$icon['bytes']||hash('sha256',$png)!==$icon['sha256'])throw new RuntimeException('Image integrity failure');
   $info=getimagesizefromstring($png);if(!$info||$info[2]!==IMAGETYPE_PNG||$info[0]!==$icon['width']||$info[1]!==$icon['height'])throw new RuntimeException('Invalid PNG dimensions');
   $image=@imagecreatefromstring($png);if(!$image)throw new RuntimeException('Undecodable PNG');imagedestroy($image);$icons[$name]=$icon;
  }
  foreach($records as $r)if($r['kind']==='entity'&&$r['fields']['icon_file']!==null&&!isset($icons[$r['fields']['icon_file']]))throw new RuntimeException('Missing image');
  foreach($profiles as $name=>$profile)if(!isset($icons[$name]))throw new RuntimeException('Missing profile asset');
  $actual=scandir($root.'/icons');if(count(array_diff($actual,['.','..']))!==count($icons))throw new RuntimeException('Unmanifested images');
  return ['id'=>hash('sha256',$raw),'manifest'=>$m,'records'=>$records,'root'=>$root];
 }
}
