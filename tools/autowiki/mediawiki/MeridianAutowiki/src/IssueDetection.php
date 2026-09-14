<?php
namespace Meridian\Autowiki;
use MediaWiki\MediaWikiServices;
use RuntimeException;

/** Complete detector scans change generated observations, never human resolutions. */
final class IssueDetection {
 public static function complete(Store $store,string $detector,string $build,array $findings,array $coveredTargets=[]):void {
  if(!in_array($detector,['source-appearance','source-decisions'],true)||!preg_match('/^[a-f0-9]{64}$/',$build))throw new RuntimeException('Invalid detector scan');
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$now=gmdate('YmdHis');
  $db->startAtomic(__METHOD__,$db::ATOMIC_CANCELABLE);try{
   $lock='detector:'.$detector;$db->insert('maw_state',['name'=>$lock,'value'=>''],__METHOD__,['IGNORE']);$db->selectField('maw_state','value',['name'=>$lock],__METHOD__,['FOR UPDATE']);
   $covered=array_fill_keys($coveredTargets,true);$previous=[];foreach($db->select('maw_issue_detection','*',['detector'=>$detector],__METHOD__) as $row)$previous[$row->id]=(array)$row;
   $seen=[];
   foreach($findings as $finding){
    [$target,$rule,$observation]=$finding;
    if(!preg_match('/^[a-f0-9]{64}$/',$target)||($detector==='source-appearance'?$rule!=='missing-appearance':!preg_match('/^(decision-conflict|asset-scope-change):[0-9]+$/',$rule)))throw new RuntimeException('Finding outside detector scope');
    $id=hash('sha256',$target.':'.$rule);if(isset($seen[$id]))throw new RuntimeException('Duplicate detector finding');$seen[$id]=true;
    $store->issue($target,$rule,$build,$observation);
    self::observe($db,$id,$detector,$build,'detected',$now,$observation,$previous[$id]??null);
   }
   // Existing installations have observations but no lifecycle rows yet. Adopt
   // only this detector's exact rules; reader reports and image reviews are separate.
   $rules=$detector==='source-appearance'?['rule'=>'missing-appearance']:["rule REGEXP '^(decision-conflict|asset-scope-change):[0-9]+$'"];
   foreach($db->select('maw_issue','*',$rules,__METHOD__) as $row){
    if(isset($seen[$row->id]))continue;
    self::observe($db,$row->id,$detector,$build,$detector==='source-appearance'&&!isset($covered[$row->target])?'source-absent':'not-detected',$now,json_decode($row->observation,true),$previous[$row->id]??null);
   }
   $db->update('maw_state',['value'=>json_encode(['build'=>$build,'checked'=>$now,'findings'=>count($seen)],JSON_THROW_ON_ERROR)],['name'=>$lock],__METHOD__);
   $db->endAtomic(__METHOD__);
  }catch(\Throwable $e){$db->cancelAtomic(__METHOD__);throw $e;}
 }
 private static function observe($db,string $id,string $detector,string $build,string $state,string $now,array $observation,?array $previous):void {
  $fingerprint=Package::fingerprint(['observation'=>$observation],['observation']);
  $row=['id'=>$id,'detector'=>$detector,'build'=>$build,'state'=>$state,'checked'=>$now,'fingerprint'=>$fingerprint];
  if(!$previous||$previous['state']!==$state||$previous['fingerprint']!==$fingerprint)$db->insert('maw_issue_event',['issue'=>$id,'detector'=>$detector,'build'=>$build,'state'=>$state,'observed'=>$now,'fingerprint'=>$fingerprint,'observation'=>json_encode($observation,JSON_THROW_ON_ERROR)],__METHOD__);
  $db->upsert('maw_issue_detection',$row,['id'],$row,__METHOD__);
 }
 public static function detail(string $id,bool $history=true,int $offset=0):?array {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$row=$db->selectRow('maw_issue_detection','*',['id'=>$id],__METHOD__);if(!$row)return null;
  $result=(array)$row;if(!$history)return $result;
  $events=[];foreach($db->select('maw_issue_event','*',['issue'=>$id],__METHOD__,['ORDER BY'=>'sequence DESC','LIMIT'=>21,'OFFSET'=>$offset]) as $event){$event=(array)$event;$event['observation']=json_decode($event['observation'],true);$events[]=$event;}
  return $result+['history'=>array_slice($events,0,20),'moreHistory'=>count($events)>20];
 }
}
