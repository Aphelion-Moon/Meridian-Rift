<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\OperationsNotifier;
class AutowikiOperationsNotifierTest extends Maintenance {
 public function execute(){
  // Private, unique fixture outbox; never use the live Discord worker directory.
  $root=sys_get_temp_dir().'/autowiki-notice-test-'.bin2hex(random_bytes(12));mkdir($root,0700);mkdir($root.'/queue',0700);
  $options=['directory'=>$root.'/state','queue'=>$root.'/queue','urls'=>['https://discord.com/api/webhooks/1/fixture_not_a_real_webhook']];
  $ok=static function($yes,$why){if(!$yes)throw new RuntimeException($why);};
  $waiting=['state'=>'waiting','findings'=>[['severity'=>'waiting','code'=>'deployment-awaiting-package','message'=>'private @everyone']]];
  $failure=['state'=>'error','findings'=>[['severity'=>'error','code'=>'delivery-failed','message'=>'private @everyone']]];
  try {
   $ok(OperationsNotifier::observe($waiting,$options)['state']==='unchanged'&&!glob($root.'/queue/*.json'),'Initial waiting must be quiet');
   $ok(OperationsNotifier::observe($failure,$options)['state']==='queued','First failure must be queued');
   $files=glob($root.'/queue/*.json');$ok(count($files)===1,'Expected one failure notice');
   $record=json_decode(file_get_contents($files[0]),true);$body=json_decode($record['request']['body'],true);
   $ok($body['allowed_mentions']['parse']===[]&&!str_contains($body['content'],'private')&&!str_contains($body['content'],'@everyone'),'Notice leaked input text or enabled mentions');
   for($i=0;$i<5;$i++)$ok(OperationsNotifier::observe($failure,$options)['state']==='unchanged','Unchanged failure repeated');
   unlink($files[0]);$ok(OperationsNotifier::observe($failure,$options)['state']==='unchanged'&&!glob($root.'/queue/*.json'),'Delivered notice was recreated');
   $ok(OperationsNotifier::observe($waiting,$options)['state']==='queued','Recovery must be queued');
   $files=glob($root.'/queue/*.json');$body=json_decode(json_decode(file_get_contents($files[0]),true)['request']['body'],true);
   $ok(str_contains($body['content'],'may still be waiting'),'Recovery incorrectly claims publication success');
   $ok(OperationsNotifier::observe($waiting,$options)['state']==='unchanged','Recovery repeated');
   $ok(OperationsNotifier::observe($failure,$options)['state']==='queued'&&count(glob($root.'/queue/*.json'))===2,'New recurrence lost');
   // Simulate a crash after queue insertion but before final state acknowledgement.
   $statePath=$root.'/state/state.json';$state=json_decode(file_get_contents($statePath),true);$state['pending']=['sequence'=>$state['sequence'],'codes'=>$state['active'],'urls'=>$options['urls'],'message'=>'Resumed fixture'];$state['active']=[];file_put_contents($statePath,json_encode($state));
   $ok(OperationsNotifier::observe($failure,$options)['state']==='queued'&&count(glob($root.'/queue/*.json'))===2,'Crash reconciliation duplicated pending delivery');
   $lock=fopen($root.'/state/state.lock','c');flock($lock,LOCK_EX);$ok(OperationsNotifier::observe($failure,$options)['state']==='busy','Concurrent observations were not serialized');flock($lock,LOCK_UN);fclose($lock);
   file_put_contents($statePath,'invalid');$thrown=false;try{OperationsNotifier::observe($failure,$options);}catch(\Throwable){$thrown=true;}$ok($thrown,'Corrupt state silently reset notification history');
   $ok(count(glob($root.'/queue/*.json'))===2,'Invalid state emitted a notice');
   $this->output("PASS operations notices: quiet waiting, deduplicated failure/recovery, recurrence, crash resume, lock, corruption and safe payload. No messages sent.\n");
  } finally {
   foreach([$root.'/queue',$root.'/state'] as $dir){foreach(glob($dir.'/*')?:[] as $file)unlink($file);if(is_dir($dir))rmdir($dir);}rmdir($root);
  }
 }
}
$maintClass=AutowikiOperationsNotifierTest::class;require RUN_MAINTENANCE_IF_MAIN;
