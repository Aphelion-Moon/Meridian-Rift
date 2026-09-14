<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Assets};

/** Read-only aggregate proof; emits no human content or credentials. */
class AutowikiAuditRecovery extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('output','Aggregate verification JSON',true,true);}
 public function execute(){
  $db=$this->getServiceContainer()->getConnectionProvider()->getPrimaryDatabase();$result=[];
  $tables=['maw_build'=>['id','source','manifest'],'maw_record'=>['build','id','kind','identity','name','fields'],'maw_edge'=>['build','src','dst','field','quantity'],'maw_public'=>['build','record','name','kind','family','payload'],'maw_release'=>['build','collection','epoch','records','prepared'],'maw_state'=>['name','value'],'maw_gate'=>['build','digest','previous','status','checked','findings'],'maw_gate_finding'=>['build','sequence','target','rule','payload'],'maw_build_summary'=>['build','counts','ready','dirty'],'maw_decision'=>['page','revision','target','type','payload'],'maw_issue'=>['id','target','rule','first_seen','last_seen','build','observation'],'maw_identity'=>['build','source','canonical'],'maw_asset'=>['build','record','hash','width','height','profile'],'maw_render'=>['build','record','profile','hash','width','height'],'maw_asset_delivery'=>['page','revision','filename','image_hash','signature','build'],'maw_guide_anchor'=>['page','target','field','anchor'],'maw_guide_use'=>['page','target','field','anchor'],'maw_dependency'=>['page','target','field']];
  $tables['maw_issue_detection']=['id','detector','build','state','checked','fingerprint'];$tables['maw_issue_event']=['sequence','issue','detector','build','state','observed','fingerprint','observation'];
  $tables['maw_publication']=['id','sequence','build','epoch','review_digest','published','publisher'];$tables['maw_published_source']=['publication','record','source_build','source_record','fingerprint'];
  $tables['maw_prepared_evidence']=['build','review_digest','public_digest','selection_digest'];
  $tables['maw_public_edge']=['build','src','dst','field','quantity'];
  $tables['maw_live_public']=$tables['maw_public'];$tables['maw_live_edge']=$tables['maw_public_edge'];
  $tables['maw_publication_plan']=['publication','digest','payload'];
  foreach($tables as $table=>$fields){$hash=hash_init('sha256');$count=0;$order=$fields[0]==='build'?array_slice($fields,0,$table==='maw_render'?3:2):[$fields[0]];if($table==='maw_published_source')$order=['publication','record'];if(in_array($table,['maw_build_summary','maw_release','maw_gate'],true))$order=['build'];if(in_array($table,['maw_edge','maw_public_edge','maw_live_edge'],true))$order=['build','src','dst','field'];if(in_array($table,['maw_guide_anchor','maw_guide_use','maw_dependency'],true))$order=$fields;
   foreach($db->select($table,$fields,[],__METHOD__,['ORDER BY'=>$order]) as $row){$values=(array)$row;if(isset($values['manifest']))$values['manifest']=hash('sha256',$values['manifest']);if($table==='maw_publication_plan')$values['payload']=hash('sha256',$values['payload']);hash_update($hash,json_encode($values,JSON_THROW_ON_ERROR)."\n");$count++;}$result[$table]=['rows'=>$count,'sha256'=>hash_final($hash)];
  }
  $hash=hash_init('sha256');$count=0;
  foreach($db->select(['page','revision','actor','slots','content'],['page_id','page_title','rev_id','rev_timestamp','content_sha1','actor_name'],['page_namespace'=>4300],__METHOD__,['ORDER BY'=>['page_id','rev_id']],['revision'=>['JOIN','rev_page=page_id'],'actor'=>['JOIN','actor_id=rev_actor'],'slots'=>['JOIN','slot_revision_id=rev_id AND slot_role_id=1'],'content'=>['JOIN','content_id=slot_content_id']]) as $row){hash_update($hash,json_encode((array)$row,JSON_THROW_ON_ERROR)."\n");$count++;}$result['human_revision_history']=['rows'=>$count,'sha256'=>hash_final($hash)];
  $hashes=[];foreach(['maw_asset','maw_render'] as $table)foreach($db->select($table,'hash',[],__METHOD__,['DISTINCT']) as $row)$hashes[$row->hash]=true;
  foreach($hashes as $hash=>$_){$path=Assets::path($hash);if(!is_file($path)||hash_file('sha256',$path)!==$hash)throw new RuntimeException('Managed image failed recovery verification');}
  $result['verified_unique_images']=count($hashes);$result['active']=(new Store())->active();file_put_contents($this->getOption('output'),json_encode($result,JSON_PRETTY_PRINT|JSON_THROW_ON_ERROR));$this->output(json_encode($result)."\n");
 }
}
$maintClass=AutowikiAuditRecovery::class;require RUN_MAINTENANCE_IF_MAIN;
