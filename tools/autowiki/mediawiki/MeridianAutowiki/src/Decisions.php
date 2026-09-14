<?php
namespace Meridian\Autowiki;
use MediaWiki\MediaWikiServices;
use MediaWiki\Title\Title;
use MediaWiki\Revision\SlotRecord;
use MediaWiki\CommentStore\CommentStoreComment;
use RuntimeException;
final class Decisions {
 public const TYPES=['annotation','alias','visibility','match','reject','family','correction','triage','report','assignment','asset','asset-reject','relink','preserve'];
 public static function validate(array $d):void {
  $required=['version','target','type','value','reason','watch','fingerprint','state'];
  if(array_diff($required,array_keys($d))||array_diff(array_keys($d),array_merge($required,['evidence']))||$d['version']!==1||!preg_match('/^[a-f0-9]{64}$/',$d['target'])||!in_array($d['type'],self::TYPES,true)||!in_array($d['state'],['active','revoked'],true))throw new RuntimeException('Invalid decision structure');
  if(isset($d['evidence'])&&(!is_array($d['evidence'])||array_keys($d['evidence'])!==['build']||!preg_match('/^[a-f0-9]{64}$/',$d['evidence']['build']??'')))throw new RuntimeException('Invalid source evidence');
  if(!is_string($d['value'])||mb_strlen($d['value'])>8000||!is_string($d['reason'])||trim($d['reason'])===''||mb_strlen($d['reason'])>2000)throw new RuntimeException('Value and explanation are required');
  if(!is_array($d['watch'])||!array_is_list($d['watch'])||count($d['watch'])>30)throw new RuntimeException('Invalid watched fields');
  foreach($d['watch'] as $field)if(!is_string($field)||!preg_match('/^[a-z_]+$/',$field))throw new RuntimeException('Invalid field');
  if(!preg_match('/^[a-f0-9]{64}$/',$d['fingerprint']))throw new RuntimeException('Missing source fingerprint');
  if($d['type']==='visibility'&&!in_array($d['value'],['public','hidden'],true))throw new RuntimeException('Visibility must be public or hidden');
  if(in_array($d['type'],['match','reject','family'],true)&&!preg_match('/^[a-f0-9]{64}$/',$d['value']))throw new RuntimeException('Select an entity identity');
  if($d['type']==='triage'&&!in_array($d['value'],['acknowledged','resolved','dismissed','open'],true))throw new RuntimeException('Invalid issue state');
  if(in_array($d['type'],['asset','asset-reject'],true))AssetDecision::value($d['value']);
  if($d['type']==='relink')Relink::value($d['value']);
  if($d['type']==='preserve')Preservation::value($d['value']);
  if($d['type']==='assignment'&&mb_strlen($d['value'])>255)throw new RuntimeException('Invalid assignee');
  if($d['type']==='correction'){json_decode($d['value'],true,32,JSON_THROW_ON_ERROR);}
  if($d['type']==='correction'&&count($d['watch'])!==1)throw new RuntimeException('A correction must watch exactly one field');
  if($d['type']==='correction'&&in_array($d['watch'][0],['documentation_id','documentation_family','documentation_visibility','parent','scope','appearance_scope','icon_source','icon_state','icon_file','deferred_fields','dynamic_fields','render_profiles','evidence','conditions','result'],true))throw new RuntimeException('Use an annotation or the dedicated identity, visibility and image controls for source metadata');
 }
 public static function canReview($user):bool {
  $s=MediaWikiServices::getInstance();return $user->isRegistered()&&!in_array('bot',$s->getUserGroupManager()->getUserGroups($user),true)&&$s->getPermissionManager()->userHasRight($user,'autowiki-review')&&!$user->getBlock();
 }
 public static function save(array $d,string $key,int $base,$user):array {
  if(!self::canReview($user))throw new RuntimeException('Human review permission required');self::validate($d);
  if(!preg_match('/^[a-f0-9]{64}$/',$key))throw new RuntimeException('Invalid decision key');
  $s=MediaWikiServices::getInstance();$title=Title::makeTitle(4300,$key);$page=$s->getWikiPageFactory()->newFromTitle($title);
  if(!$s->getPermissionManager()->userCan('edit',$user,$title))throw new RuntimeException('Page edit permission required');
  $up=$page->newPageUpdater($user);$current=$up->grabParentRevision();
  if(($current?->getId()??0)!==$base)throw new RuntimeException('Decision changed since preview; reload before saving');
  if($current){$content=$current->getContent(SlotRecord::MAIN);if(!$content)throw new RuntimeException('Decision content is unavailable; restore access before editing');$old=json_decode($content->serialize(),true);if($old['target']!==$d['target']||$old['type']!==$d['type'])throw new RuntimeException('Decision identity is immutable');if($d['state']==='revoked'){$reason=$d['reason'];$d=$old;$d['state']='revoked';$d['reason']=$reason;}}
  $up->setContent(SlotRecord::MAIN,new DecisionContent(json_encode($d,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR)));
  $rev=$up->saveRevision(CommentStoreComment::newUnsavedComment($d['reason']),$base?EDIT_UPDATE:EDIT_NEW);
  if(!$up->getStatus()->isOK())throw new RuntimeException('Decision save failed');
  return ['title'=>$title->getPrefixedText(),'revision'=>$rev?->getId()??$base,'url'=>$title->getLocalURL()];
 }
 public static function applicable(array $d,?array $record):bool {
  if(in_array($d['type'],['asset','asset-reject'],true)&&$d['watch']===['selected_profile']){
   $v=AssetDecision::value($d['value']);$selected=$record?AssetDecision::profileEvidence($record['fields'],$v['profile']??'initial-south-first-frame'):null;
   return $d['state']==='active'&&$selected!==null&&hash_equals($d['fingerprint'],Package::fingerprint(['selected_profile'=>$selected],$d['watch']));
  }
  return $d['state']==='active'&&$record!==null&&hash_equals($d['fingerprint'],Package::fingerprint($record['fields'],$d['watch']));
 }
}
