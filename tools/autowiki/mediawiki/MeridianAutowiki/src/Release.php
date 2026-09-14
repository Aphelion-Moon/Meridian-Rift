<?php
namespace Meridian\Autowiki;
use MediaWiki\MediaWikiServices;
use RuntimeException;
final class Release {
 public static function requireVerified(string $build):?array {
  $config=MediaWikiServices::getInstance()->getMainConfig();if(!$config->get('MeridianAutowikiRequireVerifiedRelease'))return null;
  $file=Assets::root().'/verified/'.$build.'.json';$deployment=$config->get('MeridianAutowikiDeploymentFile');
  if(!is_file($file)||filesize($file)>16000||!$deployment||!is_file($deployment))throw new RuntimeException('Awaiting a verified package and matching active-deployment receipt');
  $receipt=json_decode(file_get_contents($file),true,32,JSON_THROW_ON_ERROR);
  $observation=json_decode(file_get_contents($deployment),true,32,JSON_THROW_ON_ERROR);
  if(isset($observation['observedAt'])){$observed=strtotime($observation['observedAt']);if($observed===false||time()-$observed>120||$observed-time()>10)throw new RuntimeException('Active deployment observation has expired; refresh it before activation');}
  if(($receipt['version']??null)!==1||($receipt['build']??'')!==$build||!hash_equals($receipt['deploymentDigest']??'',hash_file('sha256',$deployment)))throw new RuntimeException('Deployment changed after verification; prepare the matching package');
  $assessment=GateReview::authenticated($build);
  if(!hash_equals($receipt['assessmentDigest']??'',$assessment['digest'])||$assessment['report']['report']['ok']!==true)throw new RuntimeException('Publication assessment changed or requires review; verify the release again');
  if(($assessment['report']['selectionDigest']??null)!==($receipt['selectionDigest']??''))throw new RuntimeException('Publication assessment does not cover the reviewed selection');
  return CandidatePlan::approved(new Store(),$build,$receipt['selectionDigest']??'');
 }
}
