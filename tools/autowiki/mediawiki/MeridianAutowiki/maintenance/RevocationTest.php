<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,Submission};
class AutowikiRevocationTest extends Maintenance {
 public function execute(){
  $s=$this->getServiceContainer();if($s->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated database required');$store=new Store();$store->install();$user=$s->getUserFactory()->newFromName('Moonridden');$nonce=bin2hex(random_bytes(8));$key=Package::key('entity','/obj/item/revoke_'.$nonce);
  $r=['kind'=>'entity','id'=>'/obj/item/revoke_'.$nonce,'fields'=>['name'=>'Revocation fixture','force'=>5,'icon_file'=>null]];
  $import=function($suffix,$record)use($store,$nonce,$key){$build=hash('sha256',$nonce.$suffix);$store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>false,'provenance'=>['dirty'=>true],'datasets'=>[['kind'=>'entity','count'=>1]]],'records'=>[$key=>$record]]);return $build;};
  $old=$import('old',$r);unset($r['fields']['force']);$new=$import('new',$r);$decisionKey=hash('sha256',$nonce.'decision');
  $d=['version'=>1,'target'=>$key,'type'=>'annotation','value'=>'Original explanation','reason'=>'Initial reviewed explanation','watch'=>['force'],'fingerprint'=>str_repeat('0',64),'state'=>'active'];$first=Submission::save($store,$d,$old,$decisionKey,0,$user);DeferredUpdates::doUpdates();$original=$store->decisions($key,$old)[0]['decision'];
  // The dashboard sends no evidence object; the selected source has also lost
  // the watched field. Only state and reason should change during revocation.
  $d['state']='revoked';$d['reason']='The explanation no longer applies';$d['value']='Do not replace the historical explanation';$d['watch']=['unknown_field'];
  $second=Submission::save($store,$d,$new,$decisionKey,$first['revision'],$user);DeferredUpdates::doUpdates();$row=$store->decisions($key,$new)[0];$expected=$original;$expected['state']='revoked';$expected['reason']=$d['reason'];
  if($row['decision']!==$expected||$row['revision']===$first['revision'])throw new RuntimeException('Revocation lost source evidence or failed to create its own revision');
  $prior=$s->getRevisionLookup()->getRevisionById($first['revision'])->getContent(MediaWiki\Revision\SlotRecord::MAIN)->serialize();if(json_decode($prior,true)!==$original)throw new RuntimeException('Original human revision changed');
  try{Submission::save($store,$d,$new,$decisionKey,$first['revision'],$user);throw new LogicException('Stale revocation accepted');}catch(RuntimeException $e){if(!str_contains($e->getMessage(),'changed since preview'))throw $e;}
  $this->output("PASS dashboard-shaped revocation after source-field removal retains original evidence and history, with a stale-revision guard.\n");
 }
}
$maintClass=AutowikiRevocationTest::class;require RUN_MAINTENANCE_IF_MAIN;
