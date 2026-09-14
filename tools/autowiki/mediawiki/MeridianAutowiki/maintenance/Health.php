<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\Store;
/** Read-only installed-code and schema check; no private configuration output. */
class AutowikiHealth extends Maintenance {
 public function execute(){
  $db=$this->getServiceContainer()->getConnectionProvider()->getPrimaryDatabase();$ready=true;
  foreach(['maw_issue_detection','maw_issue_event','maw_publication','maw_published_source','maw_publication_plan','maw_public_edge','maw_live_public','maw_live_edge'] as $table)$ready=$ready&&$db->tableExists($table,__METHOD__);
  $ready=$ready&&$db->fieldExists('maw_prepared_evidence','selection_digest',__METHOD__);
  $this->output(json_encode(['ready'=>$ready,'codeRoot'=>dirname((new ReflectionClass(Store::class))->getFileName(),2)])."\n");
 }
}
$maintClass=AutowikiHealth::class;require RUN_MAINTENANCE_IF_MAIN;
