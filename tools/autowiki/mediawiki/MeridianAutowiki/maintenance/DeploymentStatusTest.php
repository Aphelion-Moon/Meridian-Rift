<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\DeploymentStatus;
class AutowikiDeploymentStatusTest extends Maintenance {
 public function execute(){
  $current=['state'=>'awaiting-package','checkedAt'=>gmdate('c'),'commit'=>str_repeat('a',40),'engine'=>'516.1687','message'=>'private detail','token'=>'private detail'];
  $safe=DeploymentStatus::summarize($current);
  if($safe['state']!=='awaiting-package'||($safe['commit']??'')!==$current['commit']||str_contains(json_encode($safe),'private'))throw new RuntimeException('Status leaked private data or lost safe build identity');
  if(DeploymentStatus::summarize(array_replace($current,['checkedAt'=>'2000-01-01']))['state']!=='stale')throw new RuntimeException('Expired status was not detected');
  foreach(['test-merge-build'=>'test merges','expired-artifact'=>'expired','credential-required'=>'credential','no-matching-run'=>'workflow','no-package-artifact'=>'package','build-requested'=>'requested','build-running'=>'queued','build-uncertain'=>'duplicate','build-failed'=>'rerun all jobs','build-finished'=>'finished','builder-update-required'=>'approval','request-credential-required'=>'credential','build-request-rejected'=>'rejected','build-history-review-required'=>'history','workflow-unavailable'=>'workflow'] as $state=>$text)if(!str_contains(DeploymentStatus::summarize($current+['artifactState'=>$state])['message'],$text))throw new RuntimeException('Artifact waiting reason was lost');
  if((DeploymentStatus::summarize($current+['buildRunId'=>7])['buildRunId']??null)!==7)throw new RuntimeException('Safe GitHub run identity was lost');
  foreach(['javascript:alert(1)',-1,0,1.5,9007199254740992] as $invalid)if(isset(DeploymentStatus::summarize($current+['buildRunId'=>$invalid])['buildRunId']))throw new RuntimeException('Unsafe run identity accepted');
  if(str_contains(DeploymentStatus::summarize($current+['artifactState'=>'private detail'])['message'],'private'))throw new RuntimeException('Untrusted artifact reason leaked');
  foreach(['expired-artifact','build-failed','build-request-rejected','build-history-review-required'] as $artifact)if(!DeploymentStatus::summarize($current+['artifactState'=>$artifact])['attentionRequired'])throw new RuntimeException('Actionable generation problem lost');
  if(DeploymentStatus::summarize($current+['artifactState'=>'build-running'])['attentionRequired'])throw new RuntimeException('Running build treated as failed');
  foreach([null,'invalid',[],['checkedAt'=>[],'engine'=>[],'commit'=>[]]] as $invalid){$result=DeploymentStatus::summarize($invalid);if(!in_array($result['state'],['failed','stale'],true))throw new RuntimeException('Malformed status accepted');}
  $this->output("PASS deployment status is sanitized, bounded and stale-aware.\n");
 }
}
$maintClass=AutowikiDeploymentStatusTest::class;require RUN_MAINTENANCE_IF_MAIN;
