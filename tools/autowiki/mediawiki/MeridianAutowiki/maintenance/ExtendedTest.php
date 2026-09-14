<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,Decisions,Effective,DecisionContent};
class AutowikiExpandedTest extends Maintenance {
 private int $n=0;
 private function check($ok,$label){if(!$ok)throw new RuntimeException($label);$this->n++;$this->output("PASS $label\n");}
 public function execute(){
  $s=$this->getServiceContainer();if($s->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated test database required');
  $store=new Store();$store->install();$user=$s->getUserFactory()->newFromName('Moonridden');
  $base=json_decode(file_get_contents(__DIR__.'/../tests/wrench.json'),true,64,JSON_THROW_ON_ERROR);
  if(!$base)throw new RuntimeException('Wrench fixture is absent');
  $base['id'].='/test_'.bin2hex(random_bytes(4));$key=Package::key('entity',$base['id']);$base['key']=$key;$base['name']='Test Wrench';
  $sourceBuild=hash('sha256',$key.':source');$sourceRecords=[$key=>$base];$candidateKeys=[];foreach(['match','reject'] as $type){$candidate=$base;$candidate['id'].='/candidate_'.$type;$candidateKey=Package::key('entity',$candidate['id']);$sourceRecords[$candidateKey]=$candidate;$candidateKeys[$type]=$candidateKey;}$sourceManifest=['source'=>['commit'=>str_repeat('b',40)],'datasets'=>[['kind'=>'entity','count'=>3]],'publicationReady'=>false,'provenance'=>['dirty'=>true]];$store->import(['id'=>$sourceBuild,'manifest'=>$sourceManifest,'records'=>$sourceRecords]);
  $revisionKey='e'.substr(hash('sha256',$key),1);
  $d=['version'=>1,'target'=>$key,'type'=>'correction','value'=>'42','reason'=>'Controlled correction test','watch'=>['force'],'fingerprint'=>Package::fingerprint($base['fields'],['force']),'state'=>'active','evidence'=>['build'=>$sourceBuild]];
  $saved=Decisions::save($d,$revisionKey,0,$user);DeferredUpdates::doUpdates();
  $this->check($saved['revision']>0,'Lowercase alphabetic decision titles remain valid');
  $effective=Effective::record($base,$store->decisions($key));
  $this->check($effective['fields']['force']===42&&$base['fields']['force']!==42&&isset($effective['editorial']['force']),'Correction overlays facts with attribution without rewriting source');
  $base['fields']['force']=43;$effective=Effective::record($base,$store->decisions($key));
  $this->check($effective['fields']['force']===43&&count($effective['conflicts'])===1,'Changed evidence suppresses a stale correction');
  $bad=$d;$bad['value']='not-json';$this->check(!(new DecisionContent(json_encode($bad)))->isValid(),'Raw correction values require valid JSON');
  $bot=$s->getUserFactory()->newFromName('Autowiki Test Bot');if(!$bot->getId())$bot->addToDatabase();$s->getUserGroupManager()->addUserToGroup($bot,'bot');
  $this->check(!Decisions::canReview($bot),'Bot membership excludes human decisions even with ordinary editor rights');
  $records=[$key=>$base];$build=hash('sha256',$key.':build');$manifest=['source'=>['commit'=>str_repeat('b',40)],'datasets'=>[['kind'=>'entity','count'=>1]],'publicationReady'=>false,'provenance'=>['dirty'=>true]];
  foreach(['match','reject','annotation'] as $type){$copy=$d;$copy['type']=$type;$copy['watch']=[];$copy['fingerprint']=Package::fingerprint([],[]);$copy['value']=$type==='annotation'?'Retain editorial explanation':$candidateKeys[$type];Decisions::save($copy,hash('sha256',$key.$type),0,$user);}DeferredUpdates::doUpdates();
  $before=$store->decisions($key);$store->import(['id'=>$build,'manifest'=>$manifest,'records'=>$records]);$store->import(['id'=>$build,'manifest'=>$manifest,'records'=>$records]);
  $this->check($before===$store->decisions($key),'Accepted match, rejected pair, explanation and correction survive repeated imports');
  $store->issue($key,'test-recurring',$build,['reason'=>'Same source evidence']);$id=hash('sha256',$key.':test-recurring');$first=$store->getIssue($id);$store->issue($key,'test-recurring',$build,['reason'=>'Same source evidence']);
  $this->check($store->getIssue($id)['first_seen']===$first['first_seen'],'Repeated detector observations keep one issue and its first-seen history');
  $triage=['version'=>1,'target'=>$id,'type'=>'triage','value'=>'resolved','reason'=>'Reviewed initial evidence','watch'=>['observation'],'fingerprint'=>Package::fingerprint(['observation'=>$first['observation']],['observation']),'state'=>'active','evidence'=>['build'=>$sourceBuild]];
  $store->issue($key,'test-recurring',$build,['reason'=>'Changed evidence']);$refused=false;
  try{\Meridian\Autowiki\Submission::save($store,$triage,$build,hash('sha256',$id.':triage'),0,$user);}catch(RuntimeException){$refused=true;}
  $this->check($refused,'Issue evidence changed after preview is refused without silently rebasing the decision');
  $this->check(!$store->decisions($id),'A stale issue review creates no human revision');
  // Clear only this isolated test queue through a no-op receiver, then test a controlled delivery failure.
  while($store->pending())$store->drain(static function(){});
  $event='test-delivery:'.$key;$store->enqueue($event,'test',['record'=>$key]);$store->enqueue($event,'test',['record'=>$key]);
  $this->check(count($store->pending())===1,'Repeated enqueue uses one durable event');
  $result=$store->drain(static function(){throw new RuntimeException('Simulated unavailable receiver');});
  $this->check($result['failed']===1&&!$store->pending(),'Failed delivery remains explicit and does not loop without retry');
  $store->retry(hash('sha256',$event));$result=$store->drain(static function(){});
  $this->check($result['done']===1&&$result['failed']===0,'Failed delivery recovers through the same event');
  $this->output('SUCCESS '.$this->n." extended assertions.\n");
 }
}
$maintClass=AutowikiExpandedTest::class;require RUN_MAINTENANCE_IF_MAIN;
