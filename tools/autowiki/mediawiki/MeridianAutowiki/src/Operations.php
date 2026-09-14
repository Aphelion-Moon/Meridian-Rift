<?php
namespace Meridian\Autowiki;
/** Read-only service health. It does not classify or change human review decisions. */
final class Operations {
 public static function read(Store $store):array {
  return self::summarize($store->deliveryHealth(),$store->hasPendingDecisions(),DeploymentStatus::read());
 }
 public static function summarize(array $queue,bool $editorialPending,array $deployment,?int $now=null):array {
  $now??=time();$counts=$queue['counts'];$oldest=$queue['oldestPending'];$age=null;
  if($oldest!==null){$date=\DateTimeImmutable::createFromFormat('!YmdHis',$oldest,new \DateTimeZone('UTC'));if($date&&$date->format('YmdHis')===$oldest)$age=max(0,$now-$date->getTimestamp());}
  $findings=[];
  if($counts['failed']>0)$findings[]=['code'=>'delivery-failed','severity'=>'error','message'=>'Background deliveries failed. Inspect the private worker log, correct the cause, then use Retry delivery.'];
  if($counts['pending']>0&&($age===null||$age>=900))$findings[]=['code'=>'delivery-stalled','severity'=>'error','message'=>'Background work has waited at least 15 minutes or has an invalid timestamp. Check the existing wiki job runner.'];
  if($editorialPending)$findings[]=['code'=>'editorial-pending','severity'=>'waiting','message'=>'Recent human edits await reconciliation. The existing wiki job runner applies them.'];
  $state=$deployment['state']??'unconfigured';
  if(in_array($state,['failed','stale'],true)||($deployment['attentionRequired']??false))$findings[]=['code'=>'deployment-'.$state,'severity'=>'error','message'=>$deployment['message']];
  elseif($state!=='published')$findings[]=['code'=>'deployment-'.$state,'severity'=>'waiting','message'=>$deployment['message']??'Deployment status is not configured.'];
  $errors=count(array_filter($findings,static fn($f)=>$f['severity']==='error'));
  return ['state'=>$errors?'error':($findings?'waiting':'healthy'),'checkedAt'=>gmdate('c',$now),'queue'=>$counts,'oldestPendingAgeSeconds'=>$age,'editorialPending'=>$editorialPending,'findings'=>$findings];
 }
}
