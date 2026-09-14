<?php
namespace Meridian\Autowiki;
use MediaWiki\Content\JsonContentHandler;
final class DecisionHandler extends JsonContentHandler {
 public function __construct(){parent::__construct('meridian-decision');}
 protected function getContentClass(){return DecisionContent::class;}
 public function validateSave(\MediaWiki\Content\Content $content,\MediaWiki\Content\ValidationParams $params){
  $status=parent::validateSave($content,$params);if(!$status->isOK())return $status;
  $d=json_decode($content->serialize(),true);$page=$params->getPageIdentity();
  if($page->getNamespace()!==4300||!preg_match('/^[a-f0-9]{64}$/',$page->getDBkey()))return \StatusValue::newFatal('meridian-autowiki-error','Invalid decision identity');
  $old=\MediaWiki\MediaWikiServices::getInstance()->getRevisionLookup()->getRevisionByTitle($page);
  if($old){$priorContent=$old->getContent(\MediaWiki\Revision\SlotRecord::MAIN);if(!$priorContent)return \StatusValue::newFatal('meridian-autowiki-error','Decision content is unavailable');$prior=json_decode($priorContent->serialize(),true);if(($prior['target']??null)!==$d['target']||($prior['type']??null)!==$d['type'])return \StatusValue::newFatal('meridian-autowiki-error','Target and decision type cannot change');}
  if(!isset($d['evidence']['build']))return \StatusValue::newFatal('meridian-autowiki-error','Select a source build in the workshop before saving this decision');
  try{$prepared=Submission::prepare(new Store(),$d,$d['evidence']['build'],$old?->getId()??0);if(Package::canonical($prepared)!==Package::canonical($d))throw new \RuntimeException('Source fingerprint or scope does not match the selected evidence');}
  catch(\Throwable $e){return \StatusValue::newFatal('meridian-autowiki-error','Decision evidence is invalid; review the source build in the workshop');}
  return $status;
 }
}
