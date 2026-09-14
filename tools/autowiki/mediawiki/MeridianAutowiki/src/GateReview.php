<?php
namespace Meridian\Autowiki;
use MediaWiki\MediaWikiServices;
use RuntimeException;

/** Generated publication findings are not editorial decisions or public approval. */
final class GateReview {
 public static function authenticated(string $build):array {
  if(!preg_match('/^[a-f0-9]{64}$/',$build))throw new RuntimeException('Invalid review build');
  $root=Assets::root();$origin=$root.'/authenticated/'.$build.'.json';$file=$root.'/review-reports/'.$build.'.json';
  if(!is_file($origin)||filesize($origin)>16000||!is_file($file)||filesize($file)>64*1024*1024)throw new RuntimeException('Awaiting an authenticated review package');
  $receipt=json_decode(file_get_contents($origin),true,32,JSON_THROW_ON_ERROR);$bytes=file_get_contents($file);
  if(($receipt['version']??null)!==1||($receipt['build']??'')!==$build||!hash_equals($receipt['reportDigest']??'',hash('sha256',$bytes)))throw new RuntimeException('Review evidence changed after authentication');
  $report=json_decode($bytes,true,64,JSON_THROW_ON_ERROR);
  if(($report['version']??null)!==1||($report['build']??'')!==$build||!preg_match('/^(?:[a-f0-9]{64})?$/',$report['previous']??'invalid')||!is_bool($report['report']['ok']??null)||!is_array($report['report']['reasons']??null)||!is_array($report['report']['diff']['removed']??null))throw new RuntimeException('Invalid authenticated findings');
  return ['receipt'=>$receipt,'report'=>$report,'digest'=>hash('sha256',$bytes)];
 }
 public static function apply(Store $store,string $build,array $evidence):array {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();
  $old=$db->selectRow('maw_gate','*',['build'=>$build],__METHOD__);
  if($old&&hash_equals($old->digest,$evidence['digest']))return ['findings'=>(int)$old->findings,'unchanged'=>true];
  $data=$evidence['report'];$report=$data['report'];$findings=[];
  foreach($report['reasons'] as $reason){
   if(!is_array($reason)||!preg_match('/^[a-z][a-z0-9_-]{0,59}$/',$reason['rule']??''))throw new RuntimeException('Invalid publication finding');
   if($reason['rule']==='removed-identities')continue;
   $target='';$source=$reason['target']??'';
   if(is_string($source)&&str_starts_with($source,'/')&&isset(Package::contract()['fields'][$reason['kind']??''])){$key=Package::key($reason['kind'],$source);$target=$store->declaredRecord($build,$key)['key']??$store->historicalRecord($key)['key']??'';}
   $findings[]=['target'=>$target,'rule'=>$reason['rule'],'payload'=>$reason];
  }
  if(!$report['ok'])foreach($report['diff']['removed'] as $identity){
   if(!is_string($identity)||!str_contains($identity,':'))throw new RuntimeException('Invalid removed identity');
   [$kind,$source]=explode(':',$identity,2);if(!isset(Package::contract()['fields'][$kind])||!str_starts_with($source,'/'))throw new RuntimeException('Invalid removed record kind');
   $target=$store->declaredKey($data['previous'],Package::key($kind,$source));
   $findings[]=['target'=>$target,'rule'=>'removed-identity','payload'=>['rule'=>'removed-identity','kind'=>$kind,'target'=>$source]];
  }
  $db->startAtomic(__METHOD__,$db::ATOMIC_CANCELABLE);try{
   $db->delete('maw_gate_finding',['build'=>$build],__METHOD__);$batch=[];
   foreach($findings as $sequence=>$finding){$payload=json_encode($finding['payload'],JSON_THROW_ON_ERROR);if(strlen($payload)>60000)throw new RuntimeException('Publication finding exceeds size limit');$batch[]=['build'=>$build,'sequence'=>$sequence,'target'=>$finding['target'],'rule'=>$finding['rule'],'payload'=>$payload];if(count($batch)>=250){$db->insert('maw_gate_finding',$batch,__METHOD__);$batch=[];}}
   if($batch)$db->insert('maw_gate_finding',$batch,__METHOD__);
   $row=['build'=>$build,'digest'=>$evidence['digest'],'previous'=>$data['previous'],'status'=>$report['ok']?'passed':'review-required','checked'=>gmdate('YmdHis'),'findings'=>count($findings)];
   $db->upsert('maw_gate',$row,['build'],$row,__METHOD__);$db->update('maw_build',['status'=>$report['ok']?'staged':'review-required'],['id'=>$build],__METHOD__);$db->endAtomic(__METHOD__);
  }catch(\Throwable $e){$db->cancelAtomic(__METHOD__);throw $e;}
  return ['findings'=>count($findings),'unchanged'=>false];
 }
 public static function summary(string $build):?array {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$r=$db->selectRow('maw_gate','*',['build'=>$build],__METHOD__);
  return $r?['status'=>$r->status,'findings'=>(int)$r->findings,'previous'=>$r->previous,'checked'=>$r->checked]:null;
 }
 public static function findings(string $build,int $offset,string $query=''):array {
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();$rows=[];$conditions=['build'=>$build];
  if($query!=='')$conditions[]=$db->makeList(['rule '.$db->buildLike($db->anyString(),$query,$db->anyString()),'payload '.$db->buildLike($db->anyString(),$query,$db->anyString())],LIST_OR);
  foreach($db->select('maw_gate_finding','*',$conditions,__METHOD__,['ORDER BY'=>'sequence','OFFSET'=>$offset,'LIMIT'=>51]) as $r)$rows[]=['key'=>$r->target,'rule'=>$r->rule,'observation'=>json_decode($r->payload,true)];
  return ['gate'=>self::summary($build),'rows'=>array_slice($rows,0,50),'more'=>count($rows)>50];
 }
}
