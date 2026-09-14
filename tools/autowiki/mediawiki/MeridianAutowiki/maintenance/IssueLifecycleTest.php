<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,Submission,IssueDetection};
class IssueLifecycleTest extends Maintenance {
 public function execute(){
  $services=$this->getServiceContainer();if($services->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated database required');
  $store=new Store();$store->install();$user=$services->getUserFactory()->newFromName('Moonridden');$marker='lifecycle-'.bin2hex(random_bytes(6));$target=hash('sha256',$marker);$issue=hash('sha256',$target.':missing-appearance');$build=$store->builds()[0]['id'];$observation=['name'=>$marker,'reason'=>'Missing initial appearance'];
  $scan=fn($rows)=>IssueDetection::complete($store,'source-appearance',$build,$rows,[$target]);$finding=[$target,'missing-appearance',$observation];
  $scan([$finding]);$detail=$store->issueDetail($issue);$decision=['version'=>1,'target'=>$issue,'type'=>'triage','value'=>'dismissed','reason'=>'Reviewed missing image for this evidence','watch'=>['observation'],'fingerprint'=>$detail['fingerprint'],'state'=>'active'];
  $saved=Submission::save($store,$decision,$build,hash('sha256',$issue.':triage'),0,$user);DeferredUpdates::doUpdates();$human=$store->decisions($issue,$build);
  $scan([$finding]);if(count($store->issueDetail($issue)['detection']['history'])!==1)throw new RuntimeException('Repeated evidence duplicated history');
  $scan([]);$detail=$store->issueDetail($issue);if($detail['detection']['state']!=='not-detected'||$store->issues(0,$marker,'attention')['rows']||count($store->issues(0,$marker,'not-detected')['rows'])!==1)throw new RuntimeException('Cleared detector did not leave the attention queue');
  if(count($store->issues(0,$marker,'dismissed')['rows'])!==1||$store->decisions($issue,$build)!==$human)throw new RuntimeException('Automatic clearance overwrote human resolution');
  $scan([$finding]);if($store->issues(0,$marker,'attention')['rows'])throw new RuntimeException('Same-evidence recurrence discarded dismissal');
  $changed=$finding;$changed[2]['reason']='Different relevant evidence';$scan([$changed]);if(count($store->issues(0,$marker,'attention')['rows'])!==1)throw new RuntimeException('Changed evidence did not require review');
  if(count($store->issueDetail($issue)['detection']['history'])!==4)throw new RuntimeException('Transition history incomplete');
  $before=$store->issueDetail($issue);try{$scan([$finding,$finding]);throw new RuntimeException('Duplicate scan unexpectedly accepted');}catch(RuntimeException $e){if($e->getMessage()==='Duplicate scan unexpectedly accepted')throw $e;}
  if($store->issueDetail($issue)!==$before)throw new RuntimeException('Failed scan left partial observations or history');
  $store->issue($target,'reader-report:999999',$build,['name'=>$marker,'reason'=>'Human report']);$reader=hash('sha256',$target.':reader-report:999999');$scan([]);if(IssueDetection::detail($reader)!==null)throw new RuntimeException('Source detector cleared a reader report');
  IssueDetection::complete($store,'source-appearance',$build,[]);if($store->issueDetail($issue)['detection']['state']!=='source-absent')throw new RuntimeException('Missing source was incorrectly declared fixed');
  for($i=0;$i<22;$i++){$eventFinding=$finding;$eventFinding[2]['reason']='History fixture '.$i;$scan([$eventFinding]);}
  $newest=$store->issueDetail($issue);$older=$store->issueDetail($issue,true,20);if(count($newest['detection']['history'])!==20||!$newest['detection']['moreHistory']||!$older['detection']['history']||array_intersect(array_column($newest['detection']['history'],'sequence'),array_column($older['detection']['history'],'sequence')))throw new RuntimeException('Retained detector history does not paginate');
  // Exercise import, field-scoped conflict recurrence and same-package rescan.
  $record=json_decode(file_get_contents(__DIR__.'/../tests/wrench.json'),true);$record['id'].='/'.$marker;$key=Package::key('entity',$record['id']);$manifest=['source'=>['commit'=>str_repeat('b',40)],'datasets'=>[['kind'=>'entity','count'=>1]],'publicationReady'=>false,'provenance'=>['dirty'=>true]];
  $make=fn($suffix,$r)=>['id'=>hash('sha256',$marker.$suffix),'manifest'=>$manifest,'records'=>[$key=>$r]];
  $first=$make('original',$record);$store->import($first);$correction=['version'=>1,'target'=>$key,'type'=>'correction','value'=>'42','reason'=>'Fixture source expectation','watch'=>['force'],'fingerprint'=>Package::fingerprint($record['fields'],['force']),'state'=>'active'];
  $saved=Submission::save($store,$correction,$first['id'],hash('sha256',$key.':correction'),0,$user);DeferredUpdates::doUpdates();
  $changedRecord=$record;$changedRecord['fields']['force']+=1;$second=$make('changed',$changedRecord);$store->import($second);
  $decisionPage=MediaWiki\Title\Title::newFromText($saved['title'])->getArticleID();$conflict=hash('sha256',$key.':decision-conflict:'.$decisionPage);$conflictDetail=$store->issueDetail($conflict);if(($conflictDetail['detection']['state']??'')!=='detected')throw new RuntimeException('Import failed to detect changed decision scope');
  $thirdRecord=$changedRecord;$thirdRecord['fields']['throwforce']+=1;$third=$make('unrelated',$thirdRecord);$store->import($third);if($store->issueDetail($conflict)['fingerprint']!==$conflictDetail['fingerprint'])throw new RuntimeException('Unwatched field changed conflict evidence');
  $fourthRecord=$thirdRecord;$fourthRecord['fields']['force']+=1;$fourth=$make('relevant',$fourthRecord);$store->import($fourth);if($store->issueDetail($conflict)['fingerprint']===$conflictDetail['fingerprint'])throw new RuntimeException('Different watched source values reused generic conflict evidence');
  $correction['fingerprint']=Package::fingerprint($fourthRecord['fields'],['force']);Submission::save($store,$correction,$fourth['id'],hash('sha256',$key.':correction'),$saved['revision'],$user);DeferredUpdates::doUpdates();$store->import($fourth);
  if($store->issueDetail($conflict)['detection']['state']!=='not-detected')throw new RuntimeException('Reimport did not clear a revalidated human decision');
  $this->output("PASS complete scans, clearance, retained dismissal, recurrence, watched-field scope, failed-scan rollback, reader separation, real imports and revalidation on repeated import.\n");
 }
}
$maintClass=IssueLifecycleTest::class;require RUN_MAINTENANCE_IF_MAIN;
