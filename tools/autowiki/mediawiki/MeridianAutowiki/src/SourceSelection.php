<?php
namespace Meridian\Autowiki;

use MediaWiki\MediaWikiServices;
use RuntimeException;

/** Resolve a candidate public record without modifying either source package. */
final class SourceSelection {
 public static function record(Store $store,string $build,string $key):?array {
  $key=$store->canonicalKey($build,$key);$selection=Preservation::select($store,$build,$key);
  if($selection){
   $p=$selection['preview']['publication'];$sourceBuild=$p['sourceBuild'];$sourceKey=$p['sourceKey'];
   $raw=$store->record($sourceBuild,$sourceKey);
   if(!$raw)throw new RuntimeException('The selected published source is unavailable');
  }else{
   $sourceBuild=$build;$sourceKey=$key;$raw=$store->record($build,$key);
   if(!$raw||!$store->isPublic($key,$raw))return null;
  }
  // Preserve source addresses/fields for assets and relationship resolution. The
  // outer build/key identify the candidate reference, not its historical source.
  $result=Effective::record($raw,$store->decisions($key,$build));
  $result['build']=$build;$result['key']=$key;
  if($selection){
   $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();
   $commit=$db->selectField('maw_build','source',['id'=>$sourceBuild],__METHOD__);
   if(!$commit)throw new RuntimeException('The selected source commit is unavailable');
   $result['sourceBuild']=$sourceBuild;$result['sourceKey']=$sourceKey;$result['sourceCommit']=$commit;
   $result['preservation']=['publication'=>$p['id'],'published'=>$p['published'],'decisions'=>array_map(static fn($r)=>['page'=>$r['page'],'revision'=>$r['revision'],'reason'=>$r['decision']['reason']],$selection['decisions'])];
  }
  return $result;
 }
 /** Include deliberately retained identities absent from the replacement. */
 public static function keys(Store $store,string $build,?string $only=null):array {
  if($only!==null)return [$store->canonicalKey($build,$only)];
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$keys=[];
  foreach($db->select('maw_record','id',['build'=>$build],__METHOD__) as $row)$keys[$row->id]=true;
  foreach($db->select('maw_decision','payload',['type'=>'preserve'],__METHOD__) as $row){$d=json_decode($row->payload,true,64,JSON_THROW_ON_ERROR);if($d['state']==='active'&&Preservation::value($d['value'])['forBuild']===$build)$keys[$store->canonicalKey($build,$d['target'])]=true;}
  $keys=array_keys($keys);sort($keys,SORT_STRING);return $keys;
 }
}
