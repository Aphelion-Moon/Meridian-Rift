<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\Store;
class AutowikiOperationsIntegrationTest extends Maintenance {
 public function execute(){
  $db=$this->getServiceContainer()->getConnectionProvider()->getPrimaryDatabase();
  $server=$db->query('SELECT @@port AS port, @@datadir AS datadir',__METHOD__)->fetchObject();
  if((int)$server->port!==3307||!str_contains(str_replace('\\','/',strtolower($server->datadir)),'/restore-test/database'))throw new RuntimeException('Use the isolated restore database on port 3307');
  $store=new Store();$before=$store->deliveryHealth();$seed=bin2hex(random_bytes(16));$ids=[];
  $db->startAtomic(__METHOD__,\Wikimedia\Rdbms\IDatabase::ATOMIC_CANCELABLE);
  try {
   for($i=0;$i<153;$i++){
    $id=hash('sha256',$seed.':'.$i);$ids[]=$id;
    $db->insert('maw_outbox',['id'=>$id,'type'=>'test','payload'=>'{}','status'=>$i===0?'failed':($i===1?'pending':'done'),'created'=>$i<2?'20000101000000':gmdate('YmdHis')],__METHOD__);
   }
   $after=$store->deliveryHealth();
   foreach(['failed'=>1,'pending'=>1,'done'=>151] as $state=>$added)if($after['counts'][$state]!==$before['counts'][$state]+$added)throw new RuntimeException('Complete delivery aggregate incorrect');
   $rows=$store->deliveries();$position=array_search($ids[0],array_column($rows,'id'),true);
   if($position===false||count($rows)!==100)throw new RuntimeException('Old failure disappeared behind recent successful deliveries');
   $seenDone=false;foreach($rows as $row){if($row->status==='done')$seenDone=true;elseif($seenDone)throw new RuntimeException('Unresolved deliveries sorted behind completed work');}
  } finally { $db->cancelAtomic(__METHOD__); }
  if($store->deliveryHealth()!==$before)throw new RuntimeException('Test changed queue state');
  $this->output("PASS operations database aggregates and unresolved-first ordering; all fixture writes rolled back.\n");
 }
}
$maintClass=AutowikiOperationsIntegrationTest::class;require RUN_MAINTENANCE_IF_MAIN;
