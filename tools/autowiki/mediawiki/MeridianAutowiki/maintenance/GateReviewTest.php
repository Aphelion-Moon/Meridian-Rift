<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Package,Assets,GateReview};
class AutowikiGateReviewTest extends Maintenance {
 private int $checks=0;
 private function check(bool $ok,string $label):void {if(!$ok)throw new RuntimeException($label);$this->checks++;$this->output("PASS $label\n");}
 public function execute(){
  $s=$this->getServiceContainer();if($s->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated database required');$store=new Store();$store->install();$nonce=bin2hex(random_bytes(8));$epoch=$store->epoch();$active=$store->active();
  $entity=['kind'=>'entity','id'=>'/obj/machinery/vending/fixture_'.$nonce,'fields'=>['name'=>'Fixture vendor','icon_file'=>null]];$entityKey=Package::recordKey($entity);$vendor=$entity;$vendor['kind']='vending';$vendorKey=Package::recordKey($vendor);
  $old=$entity;$old['id'].='_removed';$oldKey=Package::recordKey($old);
  $import=function($suffix,$records)use($store,$nonce){$build=hash('sha256',$nonce.$suffix);$store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>true,'provenance'=>['dirty'=>false],'datasets'=>[['kind'=>'entity','count'=>count($records)]]],'records'=>$records]);return $build;};
  $previous=$import('previous',[$oldKey=>$old]);$build=$import('current',[$entityKey=>$entity,$vendorKey=>$vendor]);$origin=Assets::root().'/authenticated/'.$build.'.json';$filename=Assets::root().'/review-reports/'.$build.'.json';
  foreach([dirname($origin),dirname($filename)] as $dir)if(!is_dir($dir))mkdir($dir,0770,true);
  $report=['version'=>1,'build'=>$build,'previous'=>$previous,'report'=>['ok'=>false,'reasons'=>array_fill(0,51,['kind'=>'vending','rule'=>'negative-default_price','target'=>$vendor['id']]),'diff'=>['removed'=>['entity:'.$old['id']]]]];
  $write=function($data)use($origin,$filename,$build){$bytes=json_encode($data,JSON_THROW_ON_ERROR);file_put_contents($filename,$bytes);file_put_contents($origin,json_encode(['version'=>1,'build'=>$build,'commit'=>str_repeat('a',40),'reportDigest'=>hash('sha256',$bytes)]));};
  try{
   try{GateReview::authenticated($build);throw new LogicException('Unauthenticated review accepted');}catch(RuntimeException){$this->check(true,'Review requires its own origin receipt');}
   $write($report);$evidence=GateReview::authenticated($build);$result=GateReview::apply($store,$build,$evidence);
   $this->check($result['findings']===52,'Every generated finding is materialized');
   $first=GateReview::findings($build,0);$next=GateReview::findings($build,50);
   $this->check(count($first['rows'])===50&&$first['more']&&count($next['rows'])===2&&!$next['more'],'Findings paginate beyond the first screen');
   $this->check($first['rows'][0]['key']===$vendorKey&&$first['rows'][0]['key']!==$entityKey,'Dataset-qualified findings select the correct shared source address');
   $this->check($next['rows'][1]['key']===$oldKey,'Removed identities link to retained historical source evidence');
   $filtered=GateReview::findings($build,0,'removed-identity');$this->check(count($filtered['rows'])===1&&$filtered['rows'][0]['key']===$oldKey,'Findings can be searched by rule or source');
   $this->check(GateReview::apply($store,$build,$evidence)['unchanged'],'Repeated assessment produces no finding churn');
   $this->check($store->epoch()===$epoch&&$store->active()===$active&&!is_file(Assets::root().'/verified/'.$build.'.json'),'Review neither publishes nor rewrites human revisions');
   file_put_contents($filename,"\n",FILE_APPEND);try{GateReview::authenticated($build);throw new LogicException('Changed report accepted');}catch(RuntimeException $e){$this->check(str_contains($e->getMessage(),'changed'),'Changed report bytes invalidate the origin evidence');}
   $bad=$report;$bad['report']['reasons'][]=['rule'=>'oversized','target'=>str_repeat('x',61000)];$write($bad);
   try{GateReview::apply($store,$build,GateReview::authenticated($build));throw new LogicException('Oversized finding accepted');}catch(RuntimeException){$this->check(GateReview::summary($build)['findings']===52&&count(GateReview::findings($build,50)['rows'])===2,'Failed replacement retains the complete prior assessment');}
   $report['report']=['ok'=>true,'reasons'=>[],'diff'=>['removed'=>[]]];$write($report);GateReview::apply($store,$build,GateReview::authenticated($build));
   $this->check(GateReview::summary($build)['status']==='passed'&&GateReview::findings($build,0)['rows']===[]&&$store->epoch()===$epoch,'A passing reassessment clears generated findings while retaining human history');
   $report['report']=['ok'=>false,'reasons'=>[['kind'=>'entity','rule'=>'outside-export','target'=>$old['id'],'field'=>'example','related'=>'entity:/obj/item/missing']],'diff'=>['removed'=>[]]];$write($report);GateReview::apply($store,$build,GateReview::authenticated($build));
   $this->check(GateReview::findings($build,0)['rows'][0]['key']===$oldKey,'Findings on retained sources remain navigable when the replacement lacks that record');
   $this->output('SUCCESS '.$this->checks." authenticated publication-review assertions.\n");
  }finally{if(is_file($origin))unlink($origin);if(is_file($filename))unlink($filename);}
 }
}
$maintClass=AutowikiGateReviewTest::class;require RUN_MAINTENANCE_IF_MAIN;
