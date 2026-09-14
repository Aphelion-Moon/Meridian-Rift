<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Package,Assets,SearchIndex,Release,GateReview};
class AutowikiPublish extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('package','Verified immutable package',true,true);$this->addOption('expected','Prior active build, or none',true,true);$this->addOption('prepare-only','Prepare without activation so deployment evidence can be refreshed');}
 public function execute(){
  $package=Package::load($this->getOption('package'));$store=new Store();$id=$package['id'];$expected=$this->getOption('expected');$expected=$expected==='none'?'':$expected;
  Release::requireVerified($id);if($store->active()!==$expected)throw new RuntimeException('Active build changed before import');
  $store->import($package);Assets::stage($package);
  if(is_file(Assets::root().'/authenticated/'.$id.'.json'))GateReview::apply($store,$id,GateReview::authenticated($id));
  $store->reconcile();SearchIndex::prepare($store,$id);
  if($this->hasOption('prepare-only')){$this->output(json_encode(['prepared'=>$id])."\n");return;}
  $store->activate($id,$expected,$this->getServiceContainer()->getUserFactory()->newFromName('Moonridden'));
  $this->output(json_encode(['active'=>$id,'delivery'=>'queued'])."\n");
 }
}
$maintClass=AutowikiPublish::class;require RUN_MAINTENANCE_IF_MAIN;
