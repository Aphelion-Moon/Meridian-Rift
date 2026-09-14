<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Revision\SlotRecord;
use MediaWiki\Content\ContentHandler;
use MediaWiki\CommentStore\CommentStoreComment;
use MediaWiki\Deferred\DeferredUpdates;
class AutowikiComponentTest extends Maintenance {
 public function execute(){
  $s=$this->getServiceContainer();if($s->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated database required');
  $user=$s->getUserFactory()->newFromName('Moonridden');$id=bin2hex(random_bytes(8));$key=hash('sha256',$id);$title=MediaWiki\Title\Title::newFromText('User:Moonridden/Autowiki Component '.$id);$page=$s->getWikiPageFactory()->newFromTitle($title);
  $save=function($text)use($page,$title,$user){$up=$page->newPageUpdater($user);$up->grabParentRevision();$up->setContent(SlotRecord::MAIN,ContentHandler::makeContent($text,$title));$up->saveRevision(CommentStoreComment::newUnsavedComment('Isolated component test.'));if(!$up->getStatus()->isOK())throw new RuntimeException('Fixture page save failed');DeferredUpdates::doUpdates();};
  $store=new Meridian\Autowiki\Store();$store->install();$save('{{#gamefact:'.$key.'|force}}');$db=$s->getConnectionProvider()->getPrimaryDatabase();
  if(!(int)$db->selectField('maw_dependency','COUNT(*)',['page'=>$page->getId(),'target'=>$key],__METHOD__))throw new RuntimeException('An unpublished embed lost its future dependency');
  $links=$store->guideImpact($key);if(!str_contains($links[0]['url']??'','#game-'.substr($key,0,20).'-force'))throw new RuntimeException('Guide link lacks exact fact anchor');
  $save('== Procedure =='."\n".'{{#gamedependency:'.$key.'|force|Procedure}}'."\n".'Human-written instructions.');$links=$store->guideImpact($key);if(!str_ends_with($links[0]['url']??'','#Procedure'))throw new RuntimeException('Explicit prose dependency lost its section anchor');
  $save('{{Game Dependency|id='.$key.'}} Human instructions.');$links=$store->guideImpact($key);if(!$links||str_contains($links[0]['url'],'#'))throw new RuntimeException('A prose dependency without a section must link to the guide');
  $unicode=str_repeat('界',100);$mixed='{{#gamefact:'.$key.'|force}} {{#gamefact:'.$key.'|force}}'."\n".'== Procedure =='."\n".'{{Game Dependency|id='.$key.'|field=force|section=Procedure}}'."\n".'== Other =='."\n".'{{Game Dependency|id='.$key.'|field=force|section=Other}}'."\n".'== '.$unicode.' =='."\n".'{{Game Dependency|id='.$key.'|field=force|section='.$unicode.'}} {{Game Dependency|id='.$key.'|field=force}}';
  $save($mixed);$anchors=array_column($store->guideImpact($key),'anchor');$expected=['game-'.substr($key,0,20).'-force','game-'.substr($key,0,20).'-force-2','Procedure','Other',$unicode,''];sort($anchors);sort($expected);if($anchors!==$expected)throw new RuntimeException('Repeated facts or prose sections lost their distinct anchors');
  $rendered=$s->getParserFactory()->create()->parse($mixed,$title,MediaWiki\Parser\ParserOptions::newFromUser($user))->getRawText();foreach(['game-'.substr($key,0,20).'-force','game-'.substr($key,0,20).'-force-2'] as $anchor)if(substr_count($rendered,'id="'.$anchor.'"')!==1)throw new RuntimeException('A stored fact anchor does not identify exactly one rendered use');
  if((int)$db->selectField('maw_dependency','COUNT(*)',['page'=>$page->getId()],__METHOD__)!==1)throw new RuntimeException('Repeated uses duplicated purge dependencies');
  $store->install();if(count($store->guideImpact($key))!==6)throw new RuntimeException('Repeated schema migration changed current guide uses');
  $db->delete('maw_guide_use',['page'=>$page->getId()],__METHOD__);$db->insert('maw_guide_anchor',['page'=>$page->getId(),'target'=>$key,'field'=>'force','anchor'=>'Procedure'],__METHOD__);$store->install();if(($store->guideImpact($key)[0]['anchor']??'')!=='Procedure')throw new RuntimeException('Legacy anchor migration lost its section');
  $save('Human explanation with no generated reference.');if((int)$db->selectField('maw_dependency','COUNT(*)',['page'=>$page->getId()],__METHOD__))throw new RuntimeException('Removed embeds retained stale dependencies');
  if($store->guideImpact($key))throw new RuntimeException('Removed embeds retained guide sections');
  $this->output("PASS saved guide dependencies: repeated facts, multiple prose sections, Unicode, legacy migration and removal.\n");
 }
}
$maintClass=AutowikiComponentTest::class;require RUN_MAINTENANCE_IF_MAIN;
