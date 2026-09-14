<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Package,Assets,GateReview};
/** An origin receipt permits review import, never publication or search activation. */
class AutowikiReview extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('package','Authenticated immutable package directory',true,true);}
 public function execute(){
  $package=Package::load($this->getOption('package'));$build=$package['id'];$evidence=GateReview::authenticated($build);
  if(($evidence['receipt']['commit']??'')!==$package['manifest']['source']['commit'])throw new RuntimeException('Authenticated source does not match the package');
  $store=new Store();$store->import($package);Assets::stage($package);$result=GateReview::apply($store,$build,$evidence);
  $this->output(json_encode(['review'=>$build]+$result)."\n");
 }
}
$maintClass=AutowikiReview::class;require RUN_MAINTENANCE_IF_MAIN;
