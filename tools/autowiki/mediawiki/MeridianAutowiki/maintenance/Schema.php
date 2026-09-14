<?php
use MediaWiki\Maintenance\Maintenance;
require_once __DIR__.'/../src/Schema.php';
class AutowikiSchema extends Maintenance {
 public function execute(){Meridian\Autowiki\Schema::install($this->getServiceContainer()->getConnectionProvider()->getPrimaryDatabase());$this->output("Schema ready.\n");}
}
$maintClass=AutowikiSchema::class;require RUN_MAINTENANCE_IF_MAIN;
