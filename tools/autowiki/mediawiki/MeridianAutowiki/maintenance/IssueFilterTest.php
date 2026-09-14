<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Submission,Package};
class IssueFilterTest extends Maintenance {
 public function execute(){if($this->getServiceContainer()->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated database required');
  $store=new Store();$store->install();$s=$this->getServiceContainer();$user=$s->getUserFactory()->newFromName('Moonridden');$build=$store->builds()[0]['id'];$marker='queue-fixture-'.bin2hex(random_bytes(5));$target=hash('sha256',$marker);$rule=$marker;$issue=hash('sha256',$target.':'.$rule);
  $store->issue($target,$rule,$build,['name'=>$marker,'uses'=>20]);$detail=$store->issueDetail($issue);
  $d=['version'=>1,'target'=>$issue,'type'=>'triage','value'=>'resolved','reason'=>'Isolated queue filtering regression check','watch'=>['observation'],'fingerprint'=>$detail['fingerprint'],'state'=>'active'];
  Submission::save($store,$d,$build,hash('sha256',$issue.':triage'),0,$user);MediaWiki\Deferred\DeferredUpdates::doUpdates();
  if(count($store->issues(0,$marker,'attention')['rows'])!==0)throw new RuntimeException('Resolved issue was not filtered');
  if(count($store->issues(0,$marker,'resolved')['rows'])!==1)throw new RuntimeException('Resolved history missing');
  $store->issue($target,$rule,$build,['name'=>$marker,'uses'=>20]);if(count($store->issues(0,$marker,'attention')['rows'])!==0)throw new RuntimeException('Unchanged evidence reopened');
  $store->issue($target,$rule,$build,['name'=>$marker,'uses'=>21]);if(count($store->issues(0,$marker,'attention')['rows'])!==1)throw new RuntimeException('Changed evidence did not reopen');
  $d['type']='assignment';$d['value']='Moonridden';$d['fingerprint']=$store->issueDetail($issue)['fingerprint'];Submission::save($store,$d,$build,hash('sha256',$issue.':assignment'),0,$user);MediaWiki\Deferred\DeferredUpdates::doUpdates();
  if(count($store->issues(0,$marker,'all','Moonridden')['rows'])!==1||count($store->issues(0,$marker,'all','unassigned')['rows'])!==0)throw new RuntimeException('Assignment filtering failed');
  if($store->issueGroups($marker,'all','unassigned')||count($store->issueGroups($marker,'attention','Moonridden'))!==1)throw new RuntimeException('Cause groups disagree with the filtered queue');
  $this->output("PASS resolved history, unchanged evidence, scoped recurrence and assignment filters.\n");
 }
}
$maintClass=IssueFilterTest::class;require RUN_MAINTENANCE_IF_MAIN;
