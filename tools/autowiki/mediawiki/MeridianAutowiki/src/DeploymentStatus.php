<?php
namespace Meridian\Autowiki;
use MediaWiki\MediaWikiServices;
/** Only sanitized operational state is exposed to workshop reviewers. */
final class DeploymentStatus {
 public static function read():array {
  $path=MediaWikiServices::getInstance()->getMainConfig()->get('MeridianAutowikiReceiverStatus');
  if(!$path||!is_file($path)||filesize($path)>16000)return ['state'=>'unconfigured','message'=>'Deployment status is not available.'];
  try{$raw=json_decode(file_get_contents($path),true,32,JSON_THROW_ON_ERROR);}catch(\Throwable){return ['state'=>'failed','message'=>'Deployment status could not be read.'];}
  return self::summarize($raw);
 }
 public static function summarize(mixed $raw):array {
  if(!is_array($raw))return ['state'=>'failed','message'=>'Deployment status could not be read.'];
  $state=in_array($raw['state']??'',['awaiting-package','published','review-required','failed'],true)?$raw['state']:'failed';$time=is_string($raw['checkedAt']??null)?strtotime($raw['checkedAt']):false;if(!$time||time()-$time>900||$time-time()>60)$state='stale';
  $out=['state'=>$state,'checkedAt'=>$time?gmdate('c',$time):null,'message'=>match($state){'published'=>'The running game package is active.','review-required'=>'The authenticated package needs review. Open Publication Findings to inspect it; the active reference was retained.','awaiting-package'=>'Waiting for a trusted package for the running game.','stale'=>'The deployment check has not reported recently.','failed'=>'Deployment checks failed; the active reference was retained.',default=>'Deployment status unavailable.'}];
  foreach(['commit'=>40,'build'=>64] as $field=>$length)if(is_string($raw[$field]??null)&&preg_match('/^[a-f0-9]{'.$length.'}$/',$raw[$field]))$out[$field]=$raw[$field];
  if(is_string($raw['engine']??null)&&preg_match('/^\d+\.\d+$/',$raw['engine']))$out['engine']=$raw['engine'];
  if(is_int($raw['testMerges']??null))$out['testMerges']=$raw['testMerges'];
  if(is_int($raw['buildRunId']??null)&&$raw['buildRunId']>0&&$raw['buildRunId']<=9007199254740991)$out['buildRunId']=$raw['buildRunId'];
  $artifact=$raw['artifactState']??'';
  $detail=match($artifact){'test-merge-build'=>'The running game includes test merges; it needs a trusted export of that exact combined build.','no-matching-run'=>'No successful publication workflow matches the running commit.','no-package-artifact'=>'The matching workflow did not produce a publication package.','expired-artifact'=>'The matching package has expired in GitHub storage.','credential-required'=>'A dedicated GitHub read credential is needed to download the matching package.','request-credential-required'=>'Automatic generation needs its dedicated GitHub Actions service credential.','builder-update-required'=>'The selected builder reference differs from its approval or needs approval before generation can start.','workflow-unavailable'=>'The approved generation workflow is not available or enabled.','build-requested'=>'Generation was requested. The receiver will follow its GitHub run automatically.','build-running'=>'Generation is queued or running in GitHub. The active reference remains available.','build-finished'=>'Generation finished; the receiver is waiting for its verified package to become available.','build-failed'=>'Generation stopped without a usable package. Inspect the GitHub run, fix its cause, then rerun all jobs.','build-request-rejected'=>'GitHub rejected the generation request. Check service permissions and the workflow before retrying.','build-uncertain'=>'The request outcome is not confirmed. The receiver is checking GitHub and will not send a duplicate request.','build-history-review-required'=>'The request history exceeds the automatic lookup limit and needs an operations review.',default=>null};
  if($detail&&$state==='awaiting-package')$out['message'].=' '.$detail;
  $out['attentionRequired']=$state==='awaiting-package'&&in_array($artifact,['expired-artifact','build-failed','build-request-rejected','build-history-review-required'],true);
  return $out;
 }
}
