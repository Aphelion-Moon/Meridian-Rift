<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Content\ContentHandler;
use MediaWiki\Revision\SlotRecord;
use MediaWiki\CommentStore\CommentStoreComment;
class AutowikiInstallPages extends Maintenance {
 public function execute(){
  $s=$this->getServiceContainer();$user=$s->getUserFactory()->newFromName('Moonridden');if(!$user?->getId())throw new RuntimeException('Attribution account missing');
  $templates=[
   'Game Fact'=>['gamefact','Insert one current published fact.',['id'=>'Stable record ID from the workshop','field'=>'Source field name']],
   'Game Item'=>['gameitem','Insert a compact published reference card.',['id'=>'Stable record ID from the workshop']],
   'Game Icon'=>['gameicon','Insert the current published source appearance.',['id'=>'Stable record ID from the workshop','profile'=>'Appearance profile from the workshop']],
   'Game Recipe'=>['gamerecipe','Insert published recipe inputs, results and conditions.',['id'=>'Stable recipe or reaction record ID']],
   'Game Dependency'=>['gamedependency','Track a fact or scenario used by human-written instructions without adding visible content.',['id'=>'Stable record ID from the workshop','field'=>'Optional source field; blank tracks the whole record','section'=>'Section URL anchor in this guide']],
   'Game Table'=>['gametable','Compare a bounded selection of published records.',['ids'=>'Comma-separated stable record IDs, at most 50','fields'=>'Comma-separated source fields, at most 10']]
  ];$pages=[];
  foreach($templates as $name=>[$function,$description,$parameters]){
   $args=[];$data=['description'=>$description,'params'=>[],'paramOrder'=>array_keys($parameters),'format'=>'inline'];
   foreach($parameters as $parameter=>$label){$args[]='{{{'.$parameter.'|'.($parameter==='fields'?'name':($parameter==='profile'?'initial-south-first-frame':'')).'}}}';$data['params'][$parameter]=['label'=>$label,'description'=>$label,'type'=>'string','required'=>$parameter!=='profile'&&($function!=='gamedependency'||$parameter==='id')];}
   $pages['Template:'.$name]='<includeonly>{{#'.$function.':'.implode('|',$args).'}}</includeonly><noinclude>'.$description.' See [[Help:Autowiki]] for examples and review. <templatedata>'.json_encode($data,JSON_UNESCAPED_SLASHES).'</templatedata></noinclude>';
  }
  $pages['Help:Autowiki']=file_get_contents(__DIR__.'/../pages/Help.wikitext');
  foreach($pages as $name=>$text){$title=MediaWiki\Title\Title::newFromText($name);$page=$s->getWikiPageFactory()->newFromTitle($title);$updater=$page->newPageUpdater($user);$previous=$updater->grabParentRevision();
   if($previous){$this->output('Retained existing editor-owned page: '.$name."\n");continue;}
   $updater->setContent(SlotRecord::MAIN,ContentHandler::makeContent($text,$title));$updater->saveRevision(CommentStoreComment::newUnsavedComment('Add reusable game reference components and workshop guidance.'),EDIT_NEW);if(!$updater->getStatus()->isOK())throw new RuntimeException('Page creation failed');$this->output('Created '.$name."\n");
  }
  $title=MediaWiki\Title\Title::newFromText('MediaWiki:Sidebar');$page=$s->getWikiPageFactory()->newFromTitle($title);$updater=$page->newPageUpdater($user);$previous=$updater->grabParentRevision();$text=$previous?->getContent(SlotRecord::MAIN)?->serialize()??'';
  if($text&&!str_contains($text,'Special:Autowiki')){$text=rtrim($text)."\n** Special:Autowiki|Autowiki Workshop\n** Special:GameReference|Game Reference\n";$updater->setContent(SlotRecord::MAIN,ContentHandler::makeContent($text,$title));$updater->saveRevision(CommentStoreComment::newUnsavedComment('Add game reference and human review navigation.'),EDIT_UPDATE);if(!$updater->getStatus()->isOK())throw new RuntimeException('Navigation update failed');}
 }
}
$maintClass=AutowikiInstallPages::class;require RUN_MAINTENANCE_IF_MAIN;
