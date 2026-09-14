<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,Decisions,Submission,Assets,AssetPublisher,SearchIndex};
class AutowikiFeatureTest extends Maintenance {
 private int $checks=0;
 private function check(bool $ok,string $label):void{if(!$ok)throw new RuntimeException($label);$this->checks++;$this->output("PASS $label\n");}
 public function execute(){
  $s=$this->getServiceContainer();$cfg=$s->getMainConfig();if($cfg->get('DBserver')!=='127.0.0.1:3307'||!str_contains(str_replace('\\','/',$cfg->get('UploadDirectory')),'/restore-test/'))throw new RuntimeException('Isolated database and uploads required');
  $store=new Store();$store->install();$db=$s->getConnectionProvider()->getPrimaryDatabase();$user=$s->getUserFactory()->newFromName('Moonridden');$nonce=bin2hex(random_bytes(8));
  $r=['kind'=>'entity','id'=>'/obj/item/test_'.$nonce,'fields'=>['name'=>'Identity Fixture','description'=>'Unchanged explanation','icon_file'=>null]];
  $old=Package::key('entity',$r['id']);$manifest=['source'=>['commit'=>str_repeat('b',40)],'publicationReady'=>true,'provenance'=>['dirty'=>false],'datasets'=>[['kind'=>'entity','count'=>1]]];$b1=hash('sha256',$nonce.'1');$b2=hash('sha256',$nonce.'2');$b3=hash('sha256',$nonce.'3');
  $store->import(['id'=>$b1,'manifest'=>$manifest,'records'=>[$old=>$r]]);
  $d=['version'=>1,'target'=>$old,'type'=>'annotation','value'=>'Persistent human note','reason'=>'Stable identity test','watch'=>['description'],'fingerprint'=>Package::fingerprint($r['fields'],['description']),'state'=>'active','evidence'=>['build'=>$b1]];$saved=Decisions::save($d,hash('sha256',$nonce.'note'),0,$user);DeferredUpdates::doUpdates();
  $r['fields']['documentation_id']='fixture.'.$nonce;$canonical=Package::recordKey($r);$store->import(['id'=>$b2,'manifest'=>$manifest,'records'=>[$canonical=>$r]]);$r['id'].='_renamed';$store->import(['id'=>$b3,'manifest'=>$manifest,'records'=>[$canonical=>$r]]);
  $this->check($store->record($b3,$old)['key']===$canonical,'Historical source address resolves after canonical adoption and rename');
  $this->check($store->decisions($canonical)[0]['revision']===$saved['revision'],'Renamed source retains its original human revision');
  $row=$store->decisions($canonical)[0];$db->delete('maw_decision',['page'=>$row['page']],__METHOD__);$store->reconcile();$this->check($store->decisions($canonical)[0]['revision']===$saved['revision'],'Missed projection is rebuilt from wiki revision history');
  $db->update('revision',['rev_deleted'=>1],['rev_id'=>$saved['revision']],__METHOD__);$store->reconcile();$this->check(count($store->decisions($canonical))===0,'Suppressed text is removed from the editorial projection');$db->update('revision',['rev_deleted'=>0],['rev_id'=>$saved['revision']],__METHOD__);$store->reconcile();
  $this->check(count($store->decisions($canonical))===1,'Restored revision visibility rebuilds the decision');
  // Native file publication exercises the same upload API as production, on a unique disposable filename.
  $r['fields']+=['icon_source'=>'icons/obj/tools.dmi','icon_state'=>'wrench','appearance_scope'=>'initial-south-first-frame'];
  $png=Assets::root().'/fixture-'.$nonce.'.png';$img=imagecreatetruecolor(2,2);imagefill($img,0,0,imagecolorallocate($img,0,200,210));imagepng($img,$png);imagedestroy($img);$hash=hash_file('sha256',$png);$path=Assets::path($hash);if(!is_dir(dirname($path)))mkdir(dirname($path),0770,true);copy($png,$path);
  $file=$s->getRepoGroup()->getLocalRepo()->newFile('Autowiki_fixture_'.$nonce.'.png');$uploaded=$file->upload($png,'Isolated asset fixture.','Original artist attribution.',0,false,false,$user);if(!$uploaded->isOK())throw new RuntimeException('Fixture upload failed');DeferredUpdates::doUpdates();$file=$s->getRepoGroup()->getLocalRepo()->newFile($file->getName());
  $r['fields']['icon_file']='entity-'.substr($hash,0,32).'.png';$build=hash('sha256',$nonce.'asset');$store->import(['id'=>$build,'manifest'=>$manifest,'records'=>[$canonical=>$r]]);$db->insert('maw_asset',['build'=>$build,'record'=>$canonical,'hash'=>$hash,'width'=>2,'height'=>2,'profile'=>'initial-south-first-frame'],__METHOD__);
  $target=hash('sha256','wiki-file:'.$file->getName());$store->issue($target,'legacy-image',$build,['filename'=>$file->getName(),'image_hash'=>$file->getSha1()]);$issue=hash('sha256',$target.':legacy-image');$mapping=$d;$mapping['target']=$issue;$mapping['type']='asset';$mapping['value']=json_encode(['entity'=>$canonical,'filename'=>$file->getName(),'expectedImageHash'=>$file->getSha1()]);$mapping['watch']=[];
  $save=Submission::save($store,$mapping,$build,hash('sha256',$nonce.'mapping'),0,$user);DeferredUpdates::doUpdates();SearchIndex::prepare($store,$build);$store->activate($build,$store->active(),$user);
  $db->update('revision',['rev_deleted'=>1],['rev_id'=>$save['revision']],__METHOD__);$suppressed=AssetPublisher::publish($store);$this->check($suppressed['changed']===0,'Suppressed image approval cannot publish before reconciliation');$db->update('revision',['rev_deleted'=>0],['rev_id'=>$save['revision']],__METHOD__);
  $db->update('maw_decision',['revision'=>$save['revision']-1],['revision'=>$save['revision']],__METHOD__);$outdated=AssetPublisher::publish($store);$this->check($outdated['changed']===0,'Outdated approval projection cannot publish');$db->update('maw_decision',['revision'=>$save['revision']],['revision'=>$save['revision']-1,'type'=>'asset','target'=>$issue],__METHOD__);
  $first=AssetPublisher::publish($store);$second=AssetPublisher::publish($store);$this->check($first['changed']===1&&$second['changed']===0,'Reviewed image publication is repeatable without revision churn');
  $text=$s->getWikiPageFactory()->newFromTitle($file->getTitle())->getRevisionRecord()->getContent(MediaWiki\Revision\SlotRecord::MAIN)->serialize();$this->check(str_contains($text,'Original artist attribution.')&&str_contains($text,'Current Source Artwork'),'Reviewed publication preserves existing attribution');
  $img=imagecreatetruecolor(2,2);imagefill($img,0,0,imagecolorallocate($img,210,0,100));imagepng($img,$png);imagedestroy($img);$manual=$file->upload($png,'Manual fixture image.',$text,0,false,false,$user);if(!$manual->isOK())throw new RuntimeException('Manual fixture upload failed: '.json_encode($manual->getErrors()));DeferredUpdates::doUpdates();
  $result=AssetPublisher::publish($store);$this->check($result['conflicts']===1&&$result['changed']===0,'Manual image changes create a conflict instead of being overwritten');
  $this->output('SUCCESS '.$this->checks." canonical identity, recovery and native asset assertions.\n");
 }
}
$maintClass=AutowikiFeatureTest::class;require RUN_MAINTENANCE_IF_MAIN;
