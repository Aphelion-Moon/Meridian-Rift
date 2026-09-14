<?php
namespace Meridian\Autowiki;
use MediaWiki\MediaWikiServices;
use RuntimeException;

/** Append-only evidence of source records included in an actual activation. */
final class PublicationLog {
 public static function fingerprint(array $record):string {
  return hash('sha256',json_encode(Package::canonical(['kind'=>$record['kind'],'id'=>$record['id'],'fields'=>$record['fields']]),JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR));
 }
 public static function capture(Store $store,string $build):array {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$sources=[];
  foreach($db->select(['p'=>'maw_public','r'=>'maw_record'],['p.record','p.payload','r.kind','r.identity','r.fields'],['p.build'=>$build],__METHOD__,['ORDER BY'=>'p.record'],['r'=>['LEFT JOIN','r.build=p.build AND r.id=p.record']]) as $row){
   $public=json_decode($row->payload,true,64,JSON_THROW_ON_ERROR);$originBuild=$public['sourceBuild']??$build;$originKey=$public['sourceKey']??$row->record;
   $raw=$originBuild===$build&&$originKey===$row->record&&$row->fields!==null?['kind'=>$row->kind,'id'=>$row->identity,'fields'=>json_decode($row->fields,true,64,JSON_THROW_ON_ERROR)]:$store->declaredRecord($originBuild,$originKey);
   if(!$raw)throw new RuntimeException('Prepared public source is unavailable');
   $sources[]=['record'=>$row->record,'source_build'=>$originBuild,'source_record'=>$originKey,'fingerprint'=>self::fingerprint($raw)];
  }
  return $sources;
 }
 /** Caller owns the activation transaction and current human-revision locks. */
 public static function append(string $build,int $epoch,string $digest,$user,array $sources,?array $selection=null):string {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$id=hash('sha256',random_bytes(32));
  $db->insert('maw_publication',['id'=>$id,'build'=>$build,'epoch'=>$epoch,'review_digest'=>$digest,'published'=>gmdate('YmdHis'),'publisher'=>$user->getName()],__METHOD__);
  foreach(array_chunk($sources,250) as $batch)$db->insert('maw_published_source',array_map(static fn($r)=>['publication'=>$id]+$r,$batch),__METHOD__);
  $selection??=['build'=>$build,'replacements'=>[],'corrections'=>[]];$bytes=CandidatePlan::encode(CandidatePlan::snapshot($selection));$compressed=gzencode($bytes,6);if(strlen($compressed)>16000000)throw new RuntimeException('Published selection exceeds the storage limit');$db->insert('maw_publication_plan',['publication'=>$id,'digest'=>hash('sha256',$bytes),'payload'=>$compressed],__METHOD__);
  return $id;
 }
 public static function latest(string $build):?array {
  if($build==='')return null;$db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$row=$db->selectRow('maw_publication',['id','build','review_digest'],['build'=>$build],__METHOD__,['ORDER BY'=>'sequence DESC','LIMIT'=>1]);return $row?['id'=>$row->id,'build'=>$row->build,'reviewDigest'=>$row->review_digest]:null;
 }
 public static function source(Store $store,string $publication,string $key):array {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();
  $row=$db->selectRow(['p'=>'maw_publication','s'=>'maw_published_source'],['p.*','s.record','s.source_build','s.source_record','s.fingerprint'],['p.id'=>$publication,'s.record'=>$key],__METHOD__,[],['s'=>['JOIN','s.publication=p.id']]);
  if(!$row)throw new RuntimeException('Select a source record from an actual publication');
  $record=$store->declaredRecord($row->source_build,$row->source_record);
  if(!$record||!hash_equals($row->fingerprint,self::fingerprint($record)))throw new RuntimeException('Published source evidence is unavailable or changed');
  return ['id'=>$row->id,'build'=>$row->build,'published'=>$row->published,'publisher'=>$row->publisher,'sourceBuild'=>$row->source_build,'sourceKey'=>$row->source_record,'fingerprint'=>$row->fingerprint,'record'=>$record];
 }
 public static function choices(string $key,int $offset=0):array {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$rows=[];
  foreach($db->select(['p'=>'maw_publication','s'=>'maw_published_source'],['p.id','p.build','p.published','p.publisher','s.source_build'],['s.record'=>$key],__METHOD__,['ORDER BY'=>'p.sequence DESC','OFFSET'=>$offset,'LIMIT'=>51],['s'=>['JOIN','s.publication=p.id']]) as $row)$rows[]=['id'=>$row->id,'build'=>$row->build,'published'=>$row->published,'publisher'=>$row->publisher,'sourceBuild'=>$row->source_build];
  return $rows;
 }
}
