<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\Package;
use Meridian\Autowiki\Store;
class AutowikiImport extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('install','Install schema');$this->addOption('package','Immutable package directory',false,true);}
 public function execute(){ $store=new Store();if($this->hasOption('install')){$store->install();$this->output("Schema ready.\n");}if($this->hasOption('package')){$p=Package::load($this->getOption('package'));$result=$store->import($p); $result['newImages']=\Meridian\Autowiki\Assets::stage($p); $this->output(json_encode($result)."\n");} }
}
$maintClass=AutowikiImport::class;require RUN_MAINTENANCE_IF_MAIN;
