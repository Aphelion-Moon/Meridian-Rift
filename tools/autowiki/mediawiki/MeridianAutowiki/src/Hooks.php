<?php
namespace Meridian\Autowiki;
use MediaWiki\Html\Html;
use MediaWiki\Revision\SlotRecord;
final class Hooks {
 public static function searchResults($special,$out,$term):void {
  if($special->getRequest()->getInt('offset')||!SearchIndex::enabled())return;
  try{$hits=SearchIndex::search($term,5);}catch(\Throwable){wfDebugLog('MeridianAutowiki','Structured search unavailable; wiki results remain available.');return;}
  if(!$hits)return;$html=Html::element('h2',[],'Game References');
  foreach($hits as $hit)$html.=Html::rawElement('div',['class'=>'maw-card'],Html::element('a',['href'=>$hit['url']],$hit['title']).Html::element('p',[],$hit['snippet']));
  $out->addHTML($html);
 }
 public static function permissions($title,$user,$action,&$result){
  if($title->getNamespace()!==4300)return true;
  if(!Decisions::canReview($user)||in_array($action,['move','delete','editcontentmodel'],true)){$result=['meridian-autowiki-error','Editorial decisions require human review access; revoke decisions instead of deleting them.'];return false;}return true;
 }
 public static function model($model,$title,&$ok){if($title->getNamespace()===4300||$model==='meridian-decision'){$ok=$title->getNamespace()===4300&&$model==='meridian-decision';return false;}return true;}
 public static function saved($page,$user,$summary,$flags,$rev,$result):void {
  if($page->getTitle()->getNamespace()!==4300)return;
  $content=$rev->getContent(SlotRecord::MAIN);if(!$content instanceof DecisionContent)return;
  (new Store())->projectDecision($page->getId(),$rev->getId(),json_decode($content->serialize(),true));
 }
 public static function parser($parser):void {foreach(['gamefact'=>'fact','gameitem'=>'item','gameicon'=>'icon','gamerecipe'=>'recipe','gametable'=>'table','gamedependency'=>'proseDependency'] as $name=>$method)$parser->setFunctionHook($name,[self::class,$method]);}
 public static function proseDependency($parser,string $key='',string $field='',string $section=''):array {
  $key=trim($key);$field=trim($field);$section=trim($section);if(!preg_match('/^[a-f0-9]{64}$/',$key)||($field!==''&&!preg_match('/^[a-z_]+$/',$field))||mb_strlen($section)>160)return ['','isHTML'=>true,'noparse'=>true];
  self::lookup($parser,$key,$field);self::registerDependency($parser,$key,$field,$section);
  return ['','isHTML'=>true,'noparse'=>true];
 }
 private static function registerDependency($parser,string $key,string $field,string $anchor):void {
  $key=trim($key);$field=trim($field);if(!preg_match('/^[a-f0-9]{64}$/',$key)||strlen($field)>64||($field!==''&&!preg_match('/^[a-z_]+$/',$field)))return;
  $store=new Store();$canonical=$store->canonicalKey($store->active(),$key);$dependencies=$parser->getOutput()->getExtensionData('meridian-autowiki-dependencies')??[];
  $identity=hash('sha256',json_encode([$canonical,$field,$anchor],JSON_THROW_ON_ERROR));$dependencies[$identity]=['key'=>$canonical,'field'=>$field,'anchor'=>$anchor];$parser->getOutput()->setExtensionData('meridian-autowiki-dependencies',$dependencies);
 }
 private static function anchor(string $key,string $field):string {return 'game-'.substr(trim($key),0,20).($field!==''?'-'.preg_replace('/[^a-z0-9_-]/','',trim($field)):'');}
 private static function wrap($parser,string $key,string $field,string $html,string $tag='span'):array {
  $anchor=self::anchor($key,$field);$seen=$parser->getOutput()->getExtensionData('meridian-autowiki-anchors')??[];$number=($seen[$anchor]??0)+1;$seen[$anchor]=$number;$parser->getOutput()->setExtensionData('meridian-autowiki-anchors',$seen);
  $anchor.=($number>1?'-'.$number:'');self::registerDependency($parser,$key,$field,$anchor);
  return [Html::rawElement($tag,['id'=>$anchor],$html),'isHTML'=>true,'noparse'=>true];
 }
 private static function lookup($parser,string $key,string $field=''):?array {
  if(!preg_match('/^[a-f0-9]{64}$/',$key))return null;$store=new Store();$build=$store->active();$parser->getOutput()->addModuleStyles(['ext.meridianAutowiki']);$requestedKey=$key;$key=$store->canonicalKey($build,$key);
  // Wrappers register their actual rendered anchors; prose registers its explicit section.
  $r=$store->publicRecord($build,$key);if(!$r)return null;
  foreach($store->decisions($key,$build) as $d){$title=\MediaWiki\Title\Title::newFromID($d['page']);if($title)$parser->getOutput()->addTemplate($title,$d['page'],$d['revision']);}
  return $r;
 }
 public static function linksUpdated($update,$ticket):void {
  $store=new Store();$store->replaceDependencies($update->getPageId(),array_values($update->getParserOutput()->getExtensionData('meridian-autowiki-dependencies')??[]));
 }
 public static function fact($parser,string $key='',string $field=''):array {
  $r=self::lookup($parser,trim($key),trim($field));$value=$r['fields'][$field]??null;
  if(!$r||!array_key_exists($field,$r['fields']))return self::wrap($parser,$key,$field,Html::element('span',['class'=>'maw-unavailable'],'Reference unavailable'));
  $unit='';$text=Reference::fieldText($r,$field);return self::wrap($parser,$key,$field,Html::element('span',['class'=>'maw-fact','data-game-record'=>$key],$text.($unit?' '.$unit:'').(isset($r['editorial'][$field])?' (editorial correction)':'')).Reference::retained($r));
 }
 public static function item($parser,string $key=''):array {$r=self::lookup($parser,trim($key));return self::wrap($parser,$key,'',$r?Reference::card($r):Html::element('span',[],'Reference unavailable'),'div');}
 public static function icon($parser,string $key='',string $profile='initial-south-first-frame'):array {
  $profile=trim($profile);$field=$profile==='initial-south-first-frame'?'icon_file':'render_profiles';$r=self::lookup($parser,trim($key),$field);
  return self::wrap($parser,$key,$field,$r&&isset(Package::contract()['renderProfiles'][$profile])?Reference::image($r,$profile).Reference::retained($r):'');
 }
 public static function recipe($parser,string $key=''):array {
  $r=self::lookup($parser,trim($key));
  return self::wrap($parser,$key,'',$r?Reference::retained($r).Reference::facts($r,['required_reagents','required_catalysts','required_items','results','materials','reagents','reqs','parts','tools','tool_behaviors','time','required_temp','required_pressure','required_container','construction_result','construction_components','construction_alternatives','construction_needs_anchored','construction_scope','scope']):Html::element('span',[],'Reference unavailable'),'div');
 }
 public static function table($parser,string $keys='',string $fields='name'):array {
  $columns=array_slice(array_values(array_filter(array_map('trim',explode(',',$fields)))),0,10);$rows='';
  $head='';foreach($columns as $field)$head.=Html::element('th',['scope'=>'col'],ucfirst(str_replace('_',' ',$field)));
  foreach(array_slice(array_unique(array_filter(array_map('trim',explode(',',$keys)))),0,50) as $key){
   $r=self::lookup($parser,$key);if(!$r){$rows.=self::wrap($parser,$key,'',Html::element('td',['colspan'=>max(1,count($columns))],'Reference unavailable'),'tr')[0];continue;}$cells='';
   foreach($columns as $field){self::lookup($parser,$key,$field);$cells.=Html::rawElement('td',[],self::wrap($parser,$key,$field,Html::element('span',[],$field==='name'?$r['name']:Reference::fieldText($r,$field)).Reference::retained($r))[0]);}
   $rows.=self::wrap($parser,$key,'',$cells,'tr')[0];
  }
  return [Html::rawElement('table',['class'=>'wikitable maw-facts'],Html::rawElement('thead',[],Html::rawElement('tr',[],$head)).Html::rawElement('tbody',[],$rows)),'isHTML'=>true,'noparse'=>true];
 }
}
