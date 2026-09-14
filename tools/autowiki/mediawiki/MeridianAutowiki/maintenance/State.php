<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,PublicationLog};
class AutowikiState extends Maintenance {
 public function execute(){$store=new Store();$this->output(json_encode(['active'=>$store->active(),'epoch'=>$store->epoch(),'publication'=>PublicationLog::latest($store->active()),'editorialPending'=>$store->hasPendingDecisions(),'deployment'=>Meridian\Autowiki\DeploymentStatus::read()])."\n");}
}
$maintClass=AutowikiState::class;require RUN_MAINTENANCE_IF_MAIN;
