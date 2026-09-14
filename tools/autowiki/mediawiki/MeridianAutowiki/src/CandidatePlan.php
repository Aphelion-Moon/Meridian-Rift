<?php
namespace Meridian\Autowiki;

use MediaWiki\MediaWikiServices;
use RuntimeException;

/** Exact local review snapshot consumed by the independently validating publisher. */
final class CandidatePlan {
 public static function encode(array $plan):string {
  $bytes=json_encode(Package::canonical($plan),JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR);
  if(strlen($bytes)>64*1024*1024)throw new RuntimeException('The reviewed selection exceeds the publication size limit');return $bytes;
 }
 public static function snapshot(array $plan):array {return ['build'=>$plan['build'],'replacements'=>$plan['replacements'],'corrections'=>$plan['corrections']];}
 public static function previous(string $build,string $publication):array {
  $empty=['build'=>$build,'replacements'=>[],'corrections'=>[]];if($publication==='')return $empty;
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$row=$db->selectRow('maw_publication_plan','*',['publication'=>$publication],__METHOD__);
  if(!$row)throw new RuntimeException('Published selection evidence is unavailable');
  $bytes=gzdecode($row->payload,64*1024*1024);if($bytes===false||!hash_equals($row->digest,hash('sha256',$bytes)))throw new RuntimeException('Published selection evidence changed');
  $plan=json_decode($bytes,true,64,JSON_THROW_ON_ERROR);if($plan['build']!==$build)throw new RuntimeException('Published selection belongs to another build');return $plan;
 }
 public static function capture(Store $store,string $build):array {
  if(!$store->hasBuild($build))throw new RuntimeException('Import the authenticated replacement before reviewing its selection');
  $store->requireCurrentDecisions();$digest=$store->reviewDigest();$expected=$store->active();$publication=PublicationLog::latest($expected)['id']??'';
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$keys=[];
  foreach($db->select('maw_decision','payload',['type'=>['preserve','correction']],__METHOD__) as $row){$d=json_decode($row->payload,true,64,JSON_THROW_ON_ERROR);if($d['state']!=='active'||($d['type']==='preserve'&&Preservation::value($d['value'])['forBuild']!==$build))continue;$keys[$store->canonicalKey($build,$d['target'])]=true;}
  $keys=array_keys($keys);sort($keys,SORT_STRING);$replacements=[];$corrections=[];
  $store->snapshot(true);try{
   foreach($keys as $key){
    $selected=Preservation::select($store,$build,$key);
    if($selected){$p=$selected['preview']['publication'];$r=$selected['preview']['retained'];$replacements[]=['key'=>$key,'sourceBuild'=>$p['sourceBuild'],'sourceKey'=>$p['sourceKey'],'publication'=>$p['id'],'fingerprint'=>$p['fingerprint'],'record'=>['kind'=>$r['kind'],'id'=>$r['id'],'fields'=>$r['fields']],'decisions'=>array_map(static fn($d)=>['page'=>$d['page'],'revision'=>$d['revision']],$selected['decisions'])];}
    $r=SourceSelection::record($store,$build,$key);if(!$r)continue;$fields=[];foreach($r['editorial'] as $field=>$evidence)$fields[$field]=$r['fields'][$field];if($fields)$corrections[]=['key'=>$key,'fields'=>$fields];
   }
  }finally{$store->snapshot(false);}
  $plan=['version'=>1,'build'=>$build,'expected'=>$expected,'expectedPublication'=>$publication,'reviewDigest'=>$digest,'replacements'=>$replacements,'corrections'=>$corrections,'previous'=>self::previous($expected,$publication)];
  $store->requireCurrentDecisions();if(!hash_equals($digest,$store->reviewDigest())||$expected!==$store->active()||$publication!==(PublicationLog::latest($expected)['id']??''))throw new RuntimeException('Human review or active publication changed while capturing the selection');return $plan;
 }
 public static function approved(Store $store,string $build,string $digest):array {
  $file=Assets::root().'/verified-selections/'.$build.'.json';if(!preg_match('/^[a-f0-9]{64}$/',$digest)||!is_file($file)||filesize($file)>64*1024*1024)throw new RuntimeException('Awaiting verification of the current human selection');
  $bytes=file_get_contents($file);if(!hash_equals($digest,hash('sha256',$bytes))||!hash_equals($digest,hash('sha256',self::encode(self::capture($store,$build)))))throw new RuntimeException('Human selection or active publication changed after verification');return json_decode($bytes,true,64,JSON_THROW_ON_ERROR);
 }
}
