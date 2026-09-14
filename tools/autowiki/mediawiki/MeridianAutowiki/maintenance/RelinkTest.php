<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,Submission,Decisions,Effective};
class AutowikiRelinkTest extends Maintenance {
 private int $checks=0;
 private function check(bool $ok,string $label):void {if(!$ok)throw new RuntimeException($label);$this->checks++;$this->output("PASS $label\n");}
 public function execute(){
  $s=$this->getServiceContainer();if($s->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated database required');$store=new Store();$store->install();$user=$s->getUserFactory()->newFromName('Moonridden');$nonce=bin2hex(random_bytes(8));
  $old=['kind'=>'entity','id'=>'/obj/item/old_'.$nonce,'fields'=>['name'=>'Wrench fixture','description'=>'A wrench','force'=>5,'icon_file'=>null,'documentation_visibility'=>'unknown']];$oldKey=Package::recordKey($old);$new=$old;$new['id']='/obj/item/new_'.$nonce;$newKey=Package::recordKey($new);$other=$new;$other['id'].='_other';$otherKey=Package::recordKey($other);
  $import=function($suffix,$records)use($nonce,$store){$build=hash('sha256',$nonce.$suffix);$store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>false,'provenance'=>['dirty'=>true],'datasets'=>[['kind'=>'entity','count'=>count($records)]]],'records'=>$records]);return $build;};
  $b1=$import('old',[$oldKey=>$old]);$b2=$import('new',[$newKey=>$new,$otherKey=>$other]);
  $d=['version'=>1,'target'=>$oldKey,'type'=>'annotation','value'=>'Original human explanation','reason'=>'Identity fixture','watch'=>['force'],'fingerprint'=>str_repeat('0',64),'state'=>'active'];$note=Submission::save($store,$d,$b1,hash('sha256',$nonce.'note'),0,$user);DeferredUpdates::doUpdates();
  $visibility=$d;$visibility['type']='visibility';$visibility['value']='public';$visibility['watch']=[];Submission::save($store,$visibility,$b1,hash('sha256',$nonce.'visibility'),0,$user);
  $local=$d;$local['target']=$newKey;$local['value']='Independent current explanation';Submission::save($store,$local,$b2,hash('sha256',$nonce.'current'),0,$user);DeferredUpdates::doUpdates();
  $this->check($store->record($b2,$oldKey)===null&&$store->historicalRecord($oldKey)['build']===$b1,'An orphan retains inspectable historical source evidence');
  $link=$d;$link['type']='relink';$link['value']=json_encode(['candidate'=>$newKey,'previousBuild'=>$b1]);$link=Submission::prepare($store,$link,$b2,0);$saved=Submission::save($store,$link,$b2,hash('sha256',$nonce.'link'),0,$user);DeferredUpdates::doUpdates();
  $this->check($store->record($b2,$oldKey)['key']===$newKey,'An explicit human link resolves the former address');
  $guideTitle=MediaWiki\Title\Title::newFromText('User:Moonridden/Relink guide '.$nonce);$guide=$s->getWikiPageFactory()->newFromTitle($guideTitle);$up=$guide->newPageUpdater($user);$up->grabParentRevision();$up->setContent(MediaWiki\Revision\SlotRecord::MAIN,MediaWiki\Content\ContentHandler::makeContent('== Repair =='."\n".'{{Game Dependency|id='.$oldKey.'|field=force|section=Repair}}',$guideTitle));$up->saveRevision(MediaWiki\CommentStore\CommentStoreComment::newUnsavedComment('Isolated identity guide fixture'));if(!$up->getStatus()->isOK())throw new RuntimeException('Guide fixture save failed');DeferredUpdates::doUpdates();$uses=$store->guideImpact($newKey,$b2);$this->check(count($uses)===1&&str_ends_with($uses[0]['url'],'#Repair'),'Reconciled identities retain links to original guide sections');
  $effective=Effective::record($store->record($b2,$newKey),$store->decisions($newKey,$b2));$this->check(count($effective['annotations'])===2&&$store->isPublic($newKey,$store->record($b2,$newKey)),'Old and current explanations coexist without overwriting either');
  $revisions=array_column($store->decisions($newKey,$b2),'revision');$this->check(in_array($note['revision'],$revisions,true),'Relinking preserves the original human revision');
  $new['fields']['cost']=200;$b3=$import('unrelated',[$newKey=>$new]);$this->check($store->record($b3,$oldKey)['key']===$newKey,'Unrelated source changes retain the identity judgment');
  $new['fields']['name']='Different object';$b4=$import('changed',[$newKey=>$new]);$this->check($store->record($b4,$oldKey)===null&&count($store->decisions($oldKey,$b4))>=3,'Changed identity evidence stops the link while retaining human history');
  $b5=$import('returned',[$oldKey=>$old,$newKey=>$new]);$this->check($store->record($b5,$oldKey)['key']===$oldKey,'A reappearing source is never shadowed by a historical link');
  $invalid=$link;$invalid['state']='active';try{Submission::prepare($store,$invalid,$b5,0);throw new LogicException('Existing identity was relinked');}catch(RuntimeException $e){$this->check(str_contains($e->getMessage(),'still exists'),'Human relinking refuses an identity that is still present');}
  $conflict=$link;$conflict['value']=json_encode(['candidate'=>$otherKey,'previousBuild'=>$b1]);$conflict=Submission::prepare($store,$conflict,$b2,0);$second=Submission::save($store,$conflict,$b2,hash('sha256',$nonce.'conflict'),0,$user);DeferredUpdates::doUpdates();$this->check($store->record($b2,$oldKey)===null,'Conflicting active identity judgments do not choose a winner');
  $conflict['state']='revoked';Submission::save($store,$conflict,$b2,hash('sha256',$nonce.'conflict'),$second['revision'],$user);DeferredUpdates::doUpdates();$this->check($store->record($b2,$oldKey)['key']===$newKey,'Revoking a conflicting judgment restores the remaining reviewed link');
  $link['state']='revoked';Submission::save($store,$link,$b2,hash('sha256',$nonce.'link'),$saved['revision'],$user);DeferredUpdates::doUpdates();$this->check($store->record($b2,$oldKey)===null&&count(Effective::record($store->record($b2,$newKey),$store->decisions($newKey,$b2))['annotations'])===1,'Revocation separates the identities without moving or deleting notes');
  $this->output('SUCCESS '.$this->checks." manual identity reconciliation assertions.\n");
 }
}
$maintClass=AutowikiRelinkTest::class;require RUN_MAINTENANCE_IF_MAIN;
