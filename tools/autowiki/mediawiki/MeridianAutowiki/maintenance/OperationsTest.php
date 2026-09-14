<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\Operations;
class AutowikiOperationsTest extends Maintenance {
 public function execute(){
  $now=1700000000;$published=['state'=>'published','message'=>'Current'];
  $empty=['counts'=>['pending'=>0,'failed'=>0,'done'=>150],'oldestPending'=>null];
  $check=static function($ok,$message){if(!$ok)throw new RuntimeException($message);};
  $check(Operations::summarize($empty,false,$published,$now)['state']==='healthy','Idle service should be healthy');
  $waiting=Operations::summarize($empty,false,['state'=>'awaiting-package','message'=>'Awaiting trusted package'],$now);
  $check($waiting['state']==='waiting','Missing package must not masquerade as a worker failure');
  $check(Operations::summarize($empty,false,['state'=>'awaiting-package','message'=>'Generation failed','attentionRequired'=>true],$now)['state']==='error','Failed generation must need operator attention');
  $failed=$empty;$failed['counts']['failed']=1;
  $check(Operations::summarize($failed,false,$published,$now)['state']==='error','An old failure beyond 100 completed records must remain actionable');
  foreach([899=>false,900=>true,3600=>true] as $age=>$bad){$pending=$empty;$pending['counts']['pending']=1;$pending['oldestPending']=gmdate('YmdHis',$now-$age);$result=Operations::summarize($pending,false,$published,$now);$check(($result['state']==='error')===$bad,'Pending-age boundary incorrect');$check($result['oldestPendingAgeSeconds']===$age,'Pending age incorrect');}
  foreach(['invalid','20260231000000'] as $invalid){$pending['oldestPending']=$invalid;$check(Operations::summarize($pending,false,$published,$now)['state']==='error','Invalid queue age must need attention');}
  foreach(['failed','stale'] as $state)$check(Operations::summarize($empty,false,['state'=>$state,'message'=>'Safe status'],$now)['state']==='error','Receiver failure or stale heartbeat lost');
  $check(Operations::summarize($empty,true,$published,$now)['state']==='waiting','Editorial reconciliation should remain distinct from an outage');
  $this->output("PASS operations: complete failure totals, queue-age boundaries, receiver freshness and editorial separation.\n");
 }
}
$maintClass=AutowikiOperationsTest::class;require RUN_MAINTENANCE_IF_MAIN;
