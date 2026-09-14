<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Assets,PublicationLog,Preservation,Submission,Release};
/** Disposable-database helper for the real Node/PHP publication integration test. */
class AutowikiPublicationFixture extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('mode','reset, preserve, revoke, public or check',true,true);$this->addOption('build','Fixture candidate',false,true);$this->addOption('key','Fixture record identity',false,true);}
 public function execute(){
  $s=$this->getServiceContainer();$cfg=$s->getMainConfig();if($cfg->get('DBserver')!=='127.0.0.1:3307'||$cfg->get('MeridianAutowikiSearchEnabled')||!str_contains(str_replace('\\','/',Assets::root()),'/restore-test/'))throw new RuntimeException('Disposable database and package root required');
  $store=new Store();$store->install();$mode=$this->getOption('mode');
  if($mode==='reset'){$db=$s->getConnectionProvider()->getPrimaryDatabase();$db->update('maw_state',['value'=>''],['name'=>['active','search']],__METHOD__);$this->output("{\"reset\":true}\n");return;}
  $build=$this->getOption('build');$key=$this->getOption('key');
  if($mode==='public'){$r=$store->publicRecord($store->active(),$key);$this->output(json_encode($r?['record'=>$r]:['missing'=>true])."\n");return;}
  if($mode==='check'){$selection=Release::requireVerified($build);$this->output(json_encode(['approved'=>$build,'replacements'=>count($selection['replacements']??[])])."\n");return;}
  $decisionKey=hash('sha256','pipeline-fixture:'.$build.':'.$key);$prior=null;foreach($store->decisions($key,$build) as $row)if($row['decision']['type']==='preserve'&&Preservation::value($row['decision']['value'])['forBuild']===$build)$prior=$row;
  if($mode==='preserve'){$publication=PublicationLog::latest($store->active())['id'];$preview=Preservation::preview($store,$build,$key,$publication);$d=['version'=>1,'target'=>$key,'type'=>'preserve','value'=>json_encode(['forBuild'=>$build,'publication'=>$publication]),'reason'=>'Isolated fixture: retain the verified positive vending price','watch'=>['preservation'],'fingerprint'=>$preview['fingerprint'],'state'=>'active'];}
  elseif($mode==='revoke'&&$prior){$d=$prior['decision'];$d['state']='revoked';$d['reason']='Isolated fixture: require renewed source validation';}else throw new RuntimeException('Unknown fixture mode or absent decision');
  $result=Submission::save($store,$d,$build,$decisionKey,$prior['revision']??0,$s->getUserFactory()->newFromName('Moonridden'));DeferredUpdates::doUpdates();$this->output(json_encode(['revision'=>$result['revision'],'state'=>$d['state']])."\n");
 }
}
$maintClass=AutowikiPublicationFixture::class;require RUN_MAINTENANCE_IF_MAIN;
