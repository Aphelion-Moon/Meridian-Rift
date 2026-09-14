<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,CandidatePlan};
class AutowikiSelection extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('build','Authenticated imported replacement',true,true);}
 public function execute(){
  $store=new Store();$store->reconcile();$build=$this->getOption('build');$plan=CandidatePlan::capture($store,$build);$bytes=CandidatePlan::encode($plan);
  $this->output(json_encode(['build'=>$build,'bytes'=>base64_encode($bytes),'digest'=>hash('sha256',$bytes)],JSON_THROW_ON_ERROR)."\n");
 }
}
$maintClass=AutowikiSelection::class;require RUN_MAINTENANCE_IF_MAIN;
