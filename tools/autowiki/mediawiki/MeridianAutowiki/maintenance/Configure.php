<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Logging\ManualLogEntry;
use MediaWiki\SpecialPage\SpecialPage;
class AutowikiConfigure extends Maintenance {
 public function execute(){
  $s=$this->getServiceContainer();$user=$s->getUserFactory()->newFromName('Moonridden');if(!$user?->getId())throw new RuntimeException('Missing attribution account');
  $factory=$s->getService('ManageWikiModuleFactory');$perms=$factory->permissionsLocal();
  $perms->modify('user',['permissions'=>['add'=>['autowiki-review']]]);$perms->modify('sysop',['permissions'=>['add'=>['autowiki-publish']]]);
  if($perms->getErrors())throw new RuntimeException('Permission configuration rejected');$perms->commit();
  $ns=$factory->namespacesLocal();if($ns->exists(4300)&&$ns->list(4300)['name']!=='Autowiki_Decision')throw new RuntimeException('Namespace ID is occupied');
  $ns->modify(4300,['name'=>'Autowiki_Decision','searchable'=>0,'subpages'=>0,'content'=>0,'contentmodel'=>'meridian-decision','protection'=>'autowiki-review','aliases'=>[],'core'=>0,'additional'=>[]],false);
  if($ns->getErrors())throw new RuntimeException('Namespace configuration rejected');$ns->commit();
  $s->getService('ManageWikiDataStoreFactory')->newInstance($s->getMainConfig()->get('DBname'))->resetWikiData(true);
  $log=new ManualLogEntry('managewiki','namespaces');$log->setPerformer($user);$log->setTarget(SpecialPage::getTitleFor('Autowiki'));$log->setComment('Register revisioned Autowiki decisions and workshop capabilities.');$id=$log->insert();$log->publish($id);
  $this->output("Autowiki registered with ManageWiki.\n");
 }
}
$maintClass=AutowikiConfigure::class;require RUN_MAINTENANCE_IF_MAIN;
