<?php
namespace Meridian\Autowiki;
use RuntimeException;

/** An explicit, build-bound choice of previously published source data. */
final class Preservation {
 public static function value(string $value):array {
  $v=json_decode($value,true,16,JSON_THROW_ON_ERROR);
  if(!is_array($v)||count($v)!==2||array_diff(array_keys($v),['forBuild','publication']))throw new RuntimeException('Preservation needs a replacement build and a publication');
  foreach($v as $key)if(!is_string($key)||!preg_match('/^[a-f0-9]{64}$/',$key))throw new RuntimeException('Invalid preservation evidence');return $v;
 }
 public static function preview(Store $store,string $build,string $key,string $publication):array {
  if(!$store->hasBuild($build))throw new RuntimeException('Select an imported replacement build');
  $store->requireCurrentDecisions();$published=PublicationLog::source($store,$publication,$key);
  if($published['build']===$build)throw new RuntimeException('Choose an earlier publication, not the replacement itself');
  if($store->canonicalKey($build,$key)!==$key)throw new RuntimeException('Resolve the source identity before reviewing preservation');
  $retained=$published['record'];$current=$store->declaredRecord($build,$key);
  if($current&&$current['kind']!==$retained['kind'])throw new RuntimeException('Preservation cannot change a record kind');
  if(($retained['fields']['documentation_visibility']??'')==='hidden'||!$store->isPublic($retained['key'],$retained))throw new RuntimeException('The retained source is not currently eligible for public documentation');
  if($current&&(($current['fields']['documentation_visibility']??'')==='hidden'||!$store->isPublic($key,$current)))throw new RuntimeException('The replacement source is not eligible for public documentation');
  // A missing source cannot make an existing explicit restriction disappear.
  if(!$current)foreach($store->decisions($key,$build) as $row){$d=$row['decision'];if($d['state']==='active'&&$d['type']==='visibility'&&$d['value']==='hidden')throw new RuntimeException('An active human visibility restriction prevents preservation');}
  $observation=['forBuild'=>$build,'publication'=>$publication,'sourceBuild'=>$published['sourceBuild'],'sourceKey'=>$published['sourceKey'],'retained'=>$published['fingerprint'],'current'=>$current?PublicationLog::fingerprint($current):null];
  return ['publication'=>$published,'current'=>$current,'retained'=>$retained,'fingerprint'=>Package::fingerprint(['preservation'=>$observation],['preservation'])];
 }
 public static function prepare(Store $store,array $d,string $build,int $base):array {
  $v=self::value($d['value']);if(($d['state']??'')==='revoked'&&$base>0)return $d;
  if($v['forBuild']!==$build)throw new RuntimeException('The preservation preview belongs to another replacement build');
  $preview=self::preview($store,$build,$d['target'],$v['publication']);
  if(!hash_equals($preview['fingerprint'],$d['fingerprint']??''))throw new RuntimeException('Preservation evidence changed; reload the comparison before saving');
  $d['watch']=['preservation'];return $d;
 }
 public static function applicable(Store $store,array $d,string $build):bool {
  if($d['state']!=='active')return false;
  try{$v=self::value($d['value']);if($v['forBuild']!==$build)return false;return hash_equals($d['fingerprint'],self::preview($store,$build,$d['target'],$v['publication'])['fingerprint']);}
  catch(RuntimeException){return false;}
 }
 /** Identical source choices can coexist; conflicting origins have no winner. */
 public static function select(Store $store,string $build,string $key):?array {
  $options=[];
  foreach($store->decisions($key,$build) as $row){$d=$row['decision'];if($d['type']!=='preserve'||$d['state']!=='active')continue;$v=self::value($d['value']);if($v['forBuild']!==$build)continue;if(!self::applicable($store,$d,$build))throw new RuntimeException('Preservation evidence requires renewed review');$preview=self::preview($store,$build,$key,$v['publication']);$p=$preview['publication'];$identity=$p['sourceBuild'].':'.$p['sourceKey'].':'.$p['fingerprint'];$options[$identity]['preview']=$preview;$options[$identity]['decisions'][]=$row;}
  if(count($options)>1)throw new RuntimeException('Conflicting preservation decisions require review');return $options?reset($options):null;
 }
}
