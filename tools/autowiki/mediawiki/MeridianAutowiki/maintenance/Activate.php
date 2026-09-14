<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Release};
class AutowikiActivate extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('build','Verified prepared build',true,true);$this->addOption('expected','Previously active build, or none',true,true);}
 public function execute(){
  $store=new Store();$build=$this->getOption('build');Release::requireVerified($build);$expected=$this->getOption('expected');
  $store->activate($build,$expected==='none'?'':$expected,$this->getServiceContainer()->getUserFactory()->newFromName('Moonridden'));
  $this->output(json_encode(['active'=>$build])."\n");
 }
}
$maintClass=AutowikiActivate::class;require RUN_MAINTENANCE_IF_MAIN;
