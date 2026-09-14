<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,DeliveryJob};
class AutowikiReconcile extends Maintenance {
 public function execute(){
  $store=new Store();$recovered=$store->reconcile();$pending=count($store->pending());if($pending)DeliveryJob::queue();
  $this->output(json_encode(['recovered'=>$recovered,'pendingBatch'=>$pending])."\n");
 }
}
$maintClass=AutowikiReconcile::class;require RUN_MAINTENANCE_IF_MAIN;
