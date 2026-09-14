<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,SearchIndex};
class AutowikiPrepare extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('build','Validated build identity',true,true);}
 public function execute(){ $store=new Store();$store->reconcile();$this->output(json_encode(SearchIndex::prepare($store,$this->getOption('build')))."\n"); }
}
$maintClass=AutowikiPrepare::class;require RUN_MAINTENANCE_IF_MAIN;
