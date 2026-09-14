<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Assets,Release,Store,CandidatePlan};
class AutowikiReleaseTest extends Maintenance {
 public function execute(){
  $config=$this->getServiceContainer()->getMainConfig();$deployment=$config->get('MeridianAutowikiDeploymentFile');
  if($config->get('DBserver')!=='127.0.0.1:3307'||!$config->get('MeridianAutowikiRequireVerifiedRelease')||!str_contains(str_replace('\\','/',$deployment),'/restore-test/'))throw new RuntimeException('Isolated verified-release configuration required');
  $build=hash('sha256',random_bytes(32));$file=Assets::root().'/verified/'.$build.'.json';if(!is_dir(dirname($file)))mkdir(dirname($file),0770,true);if(is_file($deployment))throw new RuntimeException('Use a fresh disposable deployment receipt path');
  $store=new Store();$store->install();$store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>false,'provenance'=>['dirty'=>true],'datasets'=>[]],'records'=>[]]);$selectionBytes=CandidatePlan::encode(CandidatePlan::capture($store,$build));$selectionDigest=hash('sha256',$selectionBytes);$selection=Assets::root().'/verified-selections/'.$build.'.json';if(!is_dir(dirname($selection)))mkdir(dirname($selection),0770,true);
  $origin=Assets::root().'/authenticated/'.$build.'.json';$report=Assets::root().'/review-reports/'.$build.'.json';foreach([dirname($origin),dirname($report)] as $dir)if(!is_dir($dir))mkdir($dir,0770,true);
  $write=function($when)use($build,$file,$deployment,$origin,$report,$selection,$selectionBytes,$selectionDigest){file_put_contents($deployment,json_encode(['version'=>1,'observedAt'=>$when]));$bytes=json_encode(['version'=>1,'build'=>$build,'previous'=>'','selectionDigest'=>$selectionDigest,'report'=>['ok'=>true,'reasons'=>[],'diff'=>['removed'=>[]]]]);file_put_contents($selection,$selectionBytes);file_put_contents($report,$bytes);file_put_contents($origin,json_encode(['version'=>1,'build'=>$build,'reportDigest'=>hash('sha256',$bytes)]));file_put_contents($file,json_encode(['version'=>1,'build'=>$build,'deploymentDigest'=>hash_file('sha256',$deployment),'assessmentDigest'=>hash('sha256',$bytes),'selectionDigest'=>$selectionDigest]));};
  try{
   $write(gmdate('c'));Release::requireVerified($build);
   $write(gmdate('c',time()-300));try{Release::requireVerified($build);throw new LogicException('Expired evidence accepted');}catch(RuntimeException $e){if(!str_contains($e->getMessage(),'expired'))throw $e;}
   $write(gmdate('c'));file_put_contents($deployment,"\n",FILE_APPEND);try{Release::requireVerified($build);throw new LogicException('Changed evidence accepted');}catch(RuntimeException $e){if(!str_contains($e->getMessage(),'changed'))throw $e;}
   $write(gmdate('c'));$changed=json_decode(file_get_contents($report),true);$changed['report']['ok']=false;$bytes=json_encode($changed);file_put_contents($report,$bytes);file_put_contents($origin,json_encode(['version'=>1,'build'=>$build,'reportDigest'=>hash('sha256',$bytes)]));try{Release::requireVerified($build);throw new LogicException('Changed assessment accepted');}catch(RuntimeException $e){if(!str_contains($e->getMessage(),'assessment'))throw $e;}
   $write(gmdate('c'));file_put_contents($selection,"\n",FILE_APPEND);try{Release::requireVerified($build);throw new LogicException('Changed selection accepted');}catch(RuntimeException $e){if(!str_contains($e->getMessage(),'selection'))throw $e;}
   $this->output("PASS fresh, expired and changed deployment receipts plus changed semantic assessment and selection at the MediaWiki activation boundary.\n");
  }finally{foreach([$file,$deployment,$origin,$report,$selection] as $path)if(is_file($path))unlink($path);}
 }
}
$maintClass=AutowikiReleaseTest::class;require RUN_MAINTENANCE_IF_MAIN;
