<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Content\ContentHandler;
use MediaWiki\Revision\SlotRecord;
use MediaWiki\CommentStore\CommentStoreComment;

/** Explicit, revision-guarded upgrade; ordinary imports never edit templates. */
class AutowikiUpgradeIconTemplate extends Maintenance {
 public function execute(){
  $s=$this->getServiceContainer();$user=$s->getUserFactory()->newFromName('Moonridden');if(!$user?->getId())throw new RuntimeException('Attribution account missing');
  $title=MediaWiki\Title\Title::newFromText('Template:Game Icon');$page=$s->getWikiPageFactory()->newFromTitle($title);$updater=$page->newPageUpdater($user);$previous=$updater->grabParentRevision();$text=$previous?->getContent(SlotRecord::MAIN)?->serialize();
  if(!is_string($text))throw new RuntimeException('Install the missing template first');
  $old='{{#gameicon:{{{id|}}}}}';$new='{{#gameicon:{{{id|}}}|{{{profile|initial-south-first-frame}}}}}';
  if(substr_count($text,$old)===1)$updated=str_replace($old,$new,$text);elseif(substr_count($text,$new)===1)$updated=$text;else throw new RuntimeException('Template has a custom parser call; review it manually');
  $count=0;$updated=preg_replace_callback('/<templatedata>(.*?)<\/templatedata>/s',static function($m)use(&$count){$count++;$data=json_decode($m[1],true,512,JSON_THROW_ON_ERROR);$data['params']['profile']??=['label'=>'Appearance profile','description'=>'Profile selected in the Autowiki Workshop. Defaults to the initial appearance.','type'=>'string','required'=>false];$data['paramOrder']??=array_keys($data['params']);if(!in_array('profile',$data['paramOrder'],true))$data['paramOrder'][]='profile';return '<templatedata>'.json_encode($data,JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR).'</templatedata>';},$updated);
  if($count!==1)throw new RuntimeException('Expected one TemplateData block; review manually');
  if($updated===$text){$this->output("Game Icon already supports profiles.\n");return;}
  $updater->setContent(SlotRecord::MAIN,ContentHandler::makeContent($updated,$title));$updater->saveRevision(CommentStoreComment::newUnsavedComment('Allow an optional reviewed appearance profile in Game Icon.'),EDIT_UPDATE);if(!$updater->getStatus()->isOK())throw new RuntimeException('Template changed during upgrade or save failed');$this->output("Updated Game Icon as Moonridden; retained surrounding text.\n");
 }
}
$maintClass=AutowikiUpgradeIconTemplate::class;require RUN_MAINTENANCE_IF_MAIN;
