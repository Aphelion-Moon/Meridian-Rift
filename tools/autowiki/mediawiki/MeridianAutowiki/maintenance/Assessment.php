<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,GateReview};
class AutowikiAssessment extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('build','Authenticated imported build',true,true);}
 public function execute(){
  $store=new Store();$build=$this->getOption('build');if(!$store->hasBuild($build))throw new RuntimeException('Review import is required before assessment');
  $result=GateReview::apply($store,$build,GateReview::authenticated($build));$this->output(json_encode(['review'=>$build]+$result)."\n");
 }
}
$maintClass=AutowikiAssessment::class;require RUN_MAINTENANCE_IF_MAIN;
