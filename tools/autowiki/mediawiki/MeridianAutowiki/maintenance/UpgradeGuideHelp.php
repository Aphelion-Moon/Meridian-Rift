<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Content\ContentHandler;
use MediaWiki\Revision\SlotRecord;
use MediaWiki\CommentStore\CommentStoreComment;
/** Explicit revision-guarded documentation upgrade; imports never invoke this. */
class AutowikiUpgradeGuideHelp extends Maintenance {
 public function execute(){
  $s=$this->getServiceContainer();$user=$s->getUserFactory()->newFromName('Moonridden');if(!$user?->getId())throw new RuntimeException('Attribution account missing');
  $title=MediaWiki\Title\Title::newFromText('Help:Autowiki');$page=$s->getWikiPageFactory()->newFromTitle($title);$up=$page->newPageUpdater($user);$prior=$up->grabParentRevision();$text=$prior?->getContent(SlotRecord::MAIN)?->serialize();if(!is_string($text))throw new RuntimeException('Install Help:Autowiki first');
  $old="Embedded references register guide dependencies when the page is saved. '''Guide Impact''' lists those uses so reviewers can find affected explanations. Removing an embed removes its dependency after the page updates. The system cannot reliably infer the dependencies of arbitrary prose; explain those relationships in your review notes.";
  $source=file_get_contents(__DIR__.'/../pages/Help.wikitext');preg_match('/^Embedded references[^\r\n]+/m',$source,$match);$new=$match[0]??'';
  if(!$new)throw new RuntimeException('Source help paragraph is missing');$updated=$text;
  if(!str_contains($text,$new)){if(substr_count($text,$old)!==1||!preg_match('/'.preg_quote($old,'/').'(?=\r?\n|$)/',$text))throw new RuntimeException('Guide help has custom prose; review its current revision');$updated=str_replace($old,$new,$text);}
  if(!str_contains($updated,'== Reconnect Missing Identities ==')){preg_match('/^== Reconnect Missing Identities ==\R(.*?)(?=^== |\z)/ms',$source,$section);if(!$section||substr_count($updated,'== Use Facts in Guides ==')!==1)throw new RuntimeException('Review the identity help insertion point');$updated=str_replace('== Use Facts in Guides ==',rtrim($section[0])."\n\n".'== Use Facts in Guides ==',$updated);}
  if($updated===$text){$this->output("Guide help is current.\n");return;}
  $up->setContent(SlotRecord::MAIN,ContentHandler::makeContent($updated,$title));$up->saveRevision(CommentStoreComment::newUnsavedComment('Document guide dependencies and human reconciliation of missing source identities.'),EDIT_UPDATE);if(!$up->getStatus()->isOK())throw new RuntimeException('Guide changed during upgrade or save failed');$this->output("Updated workshop guidance as Moonridden; retained surrounding prose.\n");
 }
}
$maintClass=AutowikiUpgradeGuideHelp::class;require RUN_MAINTENANCE_IF_MAIN;
