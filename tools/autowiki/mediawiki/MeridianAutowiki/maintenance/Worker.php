<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Delivery};
class AutowikiWorker extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('retry','Retry a failed event ID',false,true);}
 public function execute(){if($this->hasOption('retry'))(new Store())->retry($this->getOption('retry'));$result=Delivery::run();$this->output(json_encode($result)."\n");if($result['failed'])$this->fatalError('One or more deliveries require review');}
}
$maintClass=AutowikiWorker::class;require RUN_MAINTENANCE_IF_MAIN;
