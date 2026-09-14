<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,Assets,SearchIndex,PublicationLog,Preservation,Submission,CandidatePlan};
class AutowikiSelectionTest extends Maintenance {
 private int $checks=0;
 private function check(bool $ok,string $label):void {if(!$ok)throw new RuntimeException($label);$this->checks++;$this->output("PASS $label\n");}
 private function refuses(callable $call,string $label):void {try{$call();throw new LogicException('Unexpected acceptance: '.$label);}catch(RuntimeException){$this->check(true,$label);}}
 public function execute(){
  $s=$this->getServiceContainer();$cfg=$s->getMainConfig();if($cfg->get('DBserver')!=='127.0.0.1:3307'||$cfg->get('MeridianAutowikiRequireVerifiedRelease')||$cfg->get('MeridianAutowikiSearchEnabled'))throw new RuntimeException('Isolated fixture configuration required');
  $store=new Store();$store->install();$db=$s->getConnectionProvider()->getPrimaryDatabase();$user=$s->getUserFactory()->newFromName('Moonridden');$nonce=bin2hex(random_bytes(8));
  $r=['kind'=>'entity','id'=>'/obj/item/selection_'.$nonce,'fields'=>['name'=>'Selection fixture','description'=>'A test item','force'=>5,'icon_file'=>null,'documentation_visibility'=>'public']];$key=Package::recordKey($r);
  $import=function($suffix,$record)use($store,$nonce,$key){$build=hash('sha256',$nonce.$suffix);$store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>true,'provenance'=>['dirty'=>false],'datasets'=>[['kind'=>'entity','count'=>1]]],'records'=>[$key=>$record]]);return $build;};
  $first=$import('first',$r);SearchIndex::prepare($store,$first);$store->activate($first,$store->active(),$user);$pub=PublicationLog::latest($first);
  $this->check(CandidatePlan::encode(CandidatePlan::previous($first,$pub['id']))===CandidatePlan::encode(CandidatePlan::snapshot(['build'=>$first,'replacements'=>[],'corrections'=>[]])),'Actual publication stores its immutable selection snapshot');
  $r['fields']['force']=9;$candidate=$import('candidate',$r);$preview=Preservation::preview($store,$candidate,$key,$pub['id']);
  $d=['version'=>1,'target'=>$key,'type'=>'preserve','value'=>json_encode(['forBuild'=>$candidate,'publication'=>$pub['id']]),'reason'=>'Keep the verified published source','watch'=>['preservation'],'fingerprint'=>$preview['fingerprint'],'state'=>'active'];$decisionKey=hash('sha256',$nonce.'preserve');$saved=Submission::save($store,$d,$candidate,$decisionKey,0,$user);DeferredUpdates::doUpdates();
  $plan=CandidatePlan::capture($store,$candidate);$bytes=CandidatePlan::encode($plan);$digest=hash('sha256',$bytes);
  $this->check($plan['expected']===$first&&$plan['expectedPublication']===$pub['id']&&$plan['reviewDigest']===$store->reviewDigest(),'The review snapshot binds the exact active publication and human revisions');
  $this->check($plan['replacements'][0]['record']['fields']['force']===5&&$plan['replacements'][0]['decisions'][0]['revision']===$saved['revision'],'The publisher receives original source fields and the authorizing native revision');
  $dir=Assets::root().'/verified-selections';if(!is_dir($dir))mkdir($dir,0770,true);$file=$dir.'/'.$candidate.'.json';
  try{
   file_put_contents($file,$bytes);$this->check(CandidatePlan::encode(CandidatePlan::approved($store,$candidate,$digest))===$bytes,'Only the exact current selection can consume approval');
   file_put_contents($file,$bytes."\n");$this->refuses(fn()=>CandidatePlan::approved($store,$candidate,$digest),'Modified selection bytes are refused');file_put_contents($file,$bytes);
   $note=['version'=>1,'target'=>$key,'type'=>'annotation','value'=>'Additional human context','reason'=>'Review changed after selection','watch'=>[],'fingerprint'=>str_repeat('0',64),'state'=>'active'];Submission::save($store,$note,$candidate,hash('sha256',$nonce.'note'),0,$user);DeferredUpdates::doUpdates();
   $this->refuses(fn()=>CandidatePlan::approved($store,$candidate,$digest),'A later human revision requires a fresh assessment');
   $plan=CandidatePlan::capture($store,$candidate);$bytes=CandidatePlan::encode($plan);$digest=hash('sha256',$bytes);file_put_contents($file,$bytes);
   SearchIndex::prepare($store,$first);$store->activate($first,$first,$user);
   $this->refuses(fn()=>CandidatePlan::approved($store,$candidate,$digest),'A new publication of the same build still invalidates the old preview');
   $currentPublication=PublicationLog::latest($first)['id'];$original=$db->selectField('maw_publication_plan','payload',['publication'=>$currentPublication],__METHOD__);$corrupt=CandidatePlan::previous($first,$currentPublication);$corrupt['build']=str_repeat('0',64);
   try{$db->update('maw_publication_plan',['payload'=>gzencode(CandidatePlan::encode($corrupt))],['publication'=>$currentPublication],__METHOD__);$this->refuses(fn()=>CandidatePlan::capture($store,$candidate),'Changed historical selection evidence stops regression comparison');}finally{$db->update('maw_publication_plan',['payload'=>$original],['publication'=>$currentPublication],__METHOD__);}
   $plan=CandidatePlan::capture($store,$candidate);$bytes=CandidatePlan::encode($plan);$digest=hash('sha256',$bytes);file_put_contents($file,$bytes);
   SearchIndex::prepare($store,$candidate);$prepared=iterator_to_array($store->publicRecords($candidate));$this->check($prepared[0]['fields']['force']===5&&$prepared[0]['sourceBuild']===$first,'Prepared references use the assessed retained source');
   $d['state']='revoked';Submission::save($store,$d,$candidate,$decisionKey,$saved['revision'],$user);DeferredUpdates::doUpdates();
   $this->refuses(fn()=>CandidatePlan::approved($store,$candidate,$digest),'Revocation invalidates the approved candidate before it can publish');
   $this->check(CandidatePlan::capture($store,$candidate)['replacements']===[]&&$store->active()===$first,'Revocation changes the next assessment without replacing the active publication');
  }finally{if(is_file($file))unlink($file);}
  $this->output('SUCCESS '.$this->checks." reviewed selection assertions.\n");
 }
}
$maintClass=AutowikiSelectionTest::class;require RUN_MAINTENANCE_IF_MAIN;
