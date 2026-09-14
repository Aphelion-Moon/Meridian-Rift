<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,Decisions,SearchIndex};
class AutowikiProjectionTest extends Maintenance {
 public function execute(){
  $s=$this->getServiceContainer();if($s->getMainConfig()->get('DBserver')!=='127.0.0.1:3307'||SearchIndex::enabled())throw new RuntimeException('Isolated database with external search disabled required');
  $store=new Store();$store->install();$store->reconcile();$db=$s->getConnectionProvider()->getPrimaryDatabase();$user=$s->getUserFactory()->newFromName('Moonridden');$nonce=bin2hex(random_bytes(8));$build=hash('sha256',$nonce);$record=['kind'=>'entity','id'=>'/obj/item/projection_'.$nonce,'fields'=>['name'=>'Projection fixture','icon_file'=>null,'documentation_visibility'=>'public']];$key=Package::recordKey($record);
  $store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>false,'provenance'=>['dirty'=>true],'datasets'=>[['kind'=>'entity','count'=>1]]],'records'=>[$key=>$record]]);
  $decision=['version'=>1,'target'=>$key,'type'=>'visibility','value'=>'public','reason'=>'Isolated projection fixture','watch'=>[],'fingerprint'=>Package::fingerprint([],[]),'state'=>'active','evidence'=>['build'=>$build]];$decisionKey=hash('sha256',$nonce.'decision');$first=Decisions::save($decision,$decisionKey,0,$user);DeferredUpdates::doUpdates();$old=$store->decisions($key)[0];
  $decision['value']='hidden';$second=Decisions::save($decision,$decisionKey,$first['revision'],$user);DeferredUpdates::doUpdates();
  // Model a missed save hook: the latest wiki revision is hidden, while the projection still says public.
  $db->update('maw_decision',['revision'=>$first['revision'],'payload'=>json_encode($old['decision'])],['page'=>$old['page']],__METHOD__);
  if(!$store->hasPendingDecisions()||$store->decisions($key)||$store->isPublic($key,$record))throw new RuntimeException('A stale public projection overrode the current human revision');
  $prepared=SearchIndex::prepare($store,$build);if($store->hasPendingDecisions()||$prepared['documents']!==0||$store->isPublic($key,$record))throw new RuntimeException('Preparation failed to reconcile current hidden evidence');
  if($store->decisions($key)[0]['revision']!==$second['revision'])throw new RuntimeException('Reconciliation changed human revision identity');
  $db->delete('maw_decision',['page'=>$old['page']],__METHOD__);if(!$store->hasPendingDecisions()||$store->isPublic($key,$record))throw new RuntimeException('A missing projection exposed a hidden record');$store->reconcile();
  $this->output("PASS current human visibility survives stale or missing projections and publication preparation repairs them.\n");
 }
}
$maintClass=AutowikiProjectionTest::class;require RUN_MAINTENANCE_IF_MAIN;
