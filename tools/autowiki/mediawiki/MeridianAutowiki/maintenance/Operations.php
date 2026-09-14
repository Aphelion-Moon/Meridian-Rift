<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Operations,OperationsNotifier,Store};
class AutowikiOperations extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('notify','Queue failure/recovery transitions through configured Discord outbox');}
 public function execute(){
  $status=Operations::read(new Store());
  if($this->hasOption('notify')){
   try {$status['notification']=OperationsNotifier::configured($status);}
   catch(\Throwable){$status['state']='error';$status['notification']=['state'=>'failed'];$status['findings'][]=['code'=>'notification-failed','severity'=>'error','message'=>'The operations notice could not be queued. Check the private Discord outbox and notification state.'];}
  }
  $this->output(json_encode($status,JSON_THROW_ON_ERROR)."\n");
  // Waiting for a trusted package is a deployment prerequisite, not a worker outage.
  if($status['state']==='error')return false;
 }
}
$maintClass=AutowikiOperations::class;require RUN_MAINTENANCE_IF_MAIN;
