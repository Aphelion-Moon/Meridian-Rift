<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Package,Store,Decisions,DecisionContent};
use MediaWiki\Deferred\DeferredUpdates;
class AutowikiTest extends Maintenance {
 private int $passed=0;
 private function check(bool $value,string $message):void{if(!$value)throw new RuntimeException($message);$this->passed++;$this->output('PASS '.$message."\n");}
 private function fails(callable $callback,string $message):void{try{$callback();}catch(Throwable){$this->check(true,$message);return;}$this->check(false,$message);}
 public function execute(){
  $s=$this->getServiceContainer();$cfg=$s->getMainConfig();if($cfg->get('DBserver')!=='127.0.0.1:3307'||$cfg->get('Server')!=='http://127.0.0.1:8099')throw new RuntimeException('Tests require the isolated recovery wiki');
  $store=new Store();$store->install();$user=$s->getUserFactory()->newFromName('Moonridden');$this->check(Decisions::canReview($user),'Human reviewer permitted');$this->check(!Decisions::canReview($s->getUserFactory()->newAnonymous()),'Anonymous writes refused');
  $id='/obj/item/autowiki_fixture_'.bin2hex(random_bytes(4));$key=Package::key('entity',$id);$fields=['name'=>'Fixture','description'=>'First','force'=>10,'icon_file'=>null];$r=['kind'=>'entity','id'=>$id,'fields'=>$fields];
  $manifest=['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>true,'provenance'=>['dirty'=>false],'datasets'=>[['kind'=>'entity','count'=>1]]];
  $b1=hash('sha256',$id.':1');$b2=hash('sha256',$id.':2');$b3=hash('sha256',$id.':3');
  $store->import(['id'=>$b1,'manifest'=>$manifest,'records'=>[$key=>$r]]);$this->check($store->import(['id'=>$b1,'manifest'=>$manifest,'records'=>[$key=>$r]])['unchanged'],'Repeat import is idempotent');
  $d=['version'=>1,'target'=>$key,'type'=>'annotation','value'=>'Keep this human explanation.','reason'=>'Integration test','watch'=>['description'],'fingerprint'=>Package::fingerprint($fields,['description']),'state'=>'active','evidence'=>['build'=>$b1]];$decisionKey=hash('sha256',$id.':decision');
  $saved=Decisions::save($d,$decisionKey,0,$user);DeferredUpdates::doUpdates();$rows=$store->decisions($key);$this->check(count($rows)===1&&$rows[0]['decision']['value']===$d['value'],'Human decision saved and projected');
  $this->fails(fn()=>Decisions::save($d,$decisionKey,0,$user),'Concurrent stale save refused');
  $bad=$d;$bad['fingerprint']=str_repeat('0',64);$this->fails(fn()=>Decisions::save($bad,hash('sha256',$id.':bad-scope'),0,$user),'Raw saves cannot forge applicability to source evidence');
  $r['fields']['force']=20;$store->import(['id'=>$b2,'manifest'=>$manifest,'records'=>[$key=>$r]]);$this->check(Decisions::applicable($store->decisions($key)[0]['decision'],$r),'Unrelated source change preserves applicability');
  $r['fields']['description']='Changed';$store->import(['id'=>$b3,'manifest'=>$manifest,'records'=>[$key=>$r]]);$rows=$store->decisions($key);$this->check($rows[0]['revision']===$saved['revision'],'Import does not rewrite human revision');$this->check(!Decisions::applicable($rows[0]['decision'],$r),'Relevant change requires revalidation');
  $empty=hash('sha256',$id.':absent');$store->import(['id'=>$empty,'manifest'=>$manifest,'records'=>[]]);$this->check(count($store->decisions($key))===1,'Absent source preserves decision');
  $expected=$store->active();\Meridian\Autowiki\SearchIndex::prepare($store,$b2);$store->activate($b2,$expected,$user);$d['value']='Later human revision';$new=Decisions::save($d,$decisionKey,$saved['revision'],$user);DeferredUpdates::doUpdates();\Meridian\Autowiki\SearchIndex::prepare($store,$b1);$store->activate($b1,$b2,$user);$this->check($store->decisions($key)[0]['revision']===$new['revision'],'Generated rollback preserves later human revision');
  $this->fails(fn()=>$store->activate($b2,$b2,$user),'Stale publication preview refused');
  $bad=$d;$bad['target']='bad';$this->check(!(new DecisionContent(json_encode($bad)))->isValid(),'Raw malformed decision content refused');
  $bad=$d;$bad['target']=hash('sha256','another');$this->fails(fn()=>Decisions::save($bad,$decisionKey,$new['revision'],$user),'Decision target is immutable');
  $this->output('SUCCESS '.$this->passed." integration assertions; isolated database only.\n");
 }
}
$maintClass=AutowikiTest::class;require RUN_MAINTENANCE_IF_MAIN;
