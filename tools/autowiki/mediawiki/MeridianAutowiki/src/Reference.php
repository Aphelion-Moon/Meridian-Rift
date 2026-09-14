<?php
namespace Meridian\Autowiki;
use MediaWiki\SpecialPage\SpecialPage;
use MediaWiki\Html\Html;
final class Reference extends SpecialPage {
 public function __construct(){parent::__construct('GameReference');}
 public static function value(mixed $v):string {if($v===null)return 'Not specified / variable';if(!is_array($v))return (string)$v;return implode('; ',array_map(static fn($p)=>self::value($p['key']).($p['value']!==null?' × '.self::value($p['value']):''),$v));}
 public static function fieldText(array $r,string $field):string {
  if(!array_key_exists($field,$r['fields']))return 'Not exposed by this adapter';
  $value=$r['fields'][$field];$deferred=array_column($r['fields']['deferred_fields']??[],'key');$dynamic=array_column($r['fields']['dynamic_fields']??[],'key');
  if($value===null&&in_array($field,$deferred,true))return 'Requires initialization; not measured';
  if($value===null&&in_array($field,$dynamic,true))return 'Runtime variable; no fixed default';
  return self::value($value).(isset(Package::contract()['units'][$field])?' '.Package::contract()['units'][$field]:'');
 }
 public static function image(array $r,string $profile='initial-south-first-frame'):string {
  $build=$r['build']??(new Store())->active();$asset=Assets::get($r['sourceBuild']??$build,$r['sourceKey']??$r['key'],$profile);if(!$asset)return '';
  $scale=min(1,96/max($asset['width'],$asset['height']));return Html::element('img',['src'=>SpecialPage::getTitleFor('AutowikiImage',$build.'/'.$r['key'].'/'.$profile)->getLocalURL(),'alt'=>$r['name'],'width'=>(int)round($asset['width']*$scale),'height'=>(int)round($asset['height']*$scale),'loading'=>'lazy','class'=>'maw-icon']);
 }
 public static function retained(array $r):string {return isset($r['preservation'])?Html::element('span',['class'=>'maw-retained','title'=>'Source build '.$r['sourceBuild'].' · Commit '.$r['sourceCommit']],'Retained documentation from an earlier build'):'';}
 public static function card(array $r):string {$url=SpecialPage::getTitleFor('GameReference',$r['key'])->getLocalURL();return Html::rawElement('div',['class'=>'maw-card'],Html::element('a',['href'=>$url],$r['name']).self::retained($r).Html::element('p',[],strip_tags($r['fields']['description']??$r['fields']['desc']??'')));}
 public function execute($subpage){
  $this->setHeaders();$out=$this->getOutput();$store=new Store();$build=$store->active();$key=(string)$subpage;
  if(!$build){$out->addHTML(Html::element('p',[],'Game reference data is being prepared. Existing guides remain available.'));return;}
  $out->addModuleStyles('ext.meridianAutowiki');
  if(!preg_match('/^[a-f0-9]{64}$/',$key)){$this->catalogue($store,$build);return;}
  $r=$store->publicRecord($build,$key);if(!$r){$out->addHTML(Html::element('p',[],'This reference is not published.'));return;}$key=$r['key'];
  $out->setPageTitle($r['name']);$out->addHTML(self::image($r).self::card($r));
  $out->addHTML(Html::element('p',[],'Source defaults. Availability and initialized behavior can differ. Source build '.($r['sourceBuild']??$build)));
  foreach($r['annotations'] as $note)$out->addHTML(Html::element('p',[],$note));
  if($r['conflicts'])$out->addHTML(Html::element('p',['class'=>'maw-unavailable'],'Some editorial decisions need revalidation against this build. Extracted values are shown.'));
  $out->addHTML(self::facts($r,['force','throwforce','weight_class','tool_behavior','tool_speed','cost','metabolization_rate','overdose_threshold','required_temp','optimal_ph_min','optimal_ph_max','time','construction_time','stock_part_tier','stock_part_energy_rating','construction_needs_anchored','construction_scope']));
  $rows='';foreach($store->view($build)->related($key) as $edge){
   $other=$edge['record'];
   $link=Html::element('a',['href'=>SpecialPage::getTitleFor('GameReference',$other['key'])->getLocalURL()],$other['name']);
   $rows.=Html::rawElement('tr',[],Html::element('td',[],$edge['direction']==='uses'?'Requires / produces':'Obtained from / used by').Html::element('td',[],str_replace('_',' ',$edge['field'])).Html::rawElement('td',[],$link).Html::element('td',[],self::value($edge['quantity'])));
  }
  if($rows)$out->addHTML(Html::element('h2',[],'Acquisition and Uses').Html::rawElement('table',['class'=>'wikitable'],$rows));
  $out->addHTML(Html::rawElement('details',[],Html::element('summary',[],'All Source Fields').self::facts($r)));
  $url=SpecialPage::getTitleFor('Autowiki')->getLocalURL(['awbuild'=>$build,'awrecord'=>$key]);
  $out->addHTML(Html::element('a',['href'=>$url],'Report an Issue or Add an Explanation'));
 }
 public static function facts(array $r,array $fields=[]):string {
  $rows='';$units=Package::contract()['units'];foreach($r['fields'] as $field=>$value){
   if($fields&&!in_array($field,$fields,true))continue;
   $text=self::fieldText($r,$field);
   if(isset($r['editorial'][$field]))$text.=' · Editorial correction: '.$r['editorial'][$field]['reason'];
   $rows.=Html::rawElement('tr',['id'=>'fact-'.$field],Html::element('th',['scope'=>'row'],ucfirst(str_replace('_',' ',$field))).Html::element('td',[],$text));
  }return Html::rawElement('table',['class'=>'wikitable maw-facts'],$rows);
 }
 private function catalogue(Store $store,string $build):void {
  $out=$this->getOutput();$q=mb_substr($this->getRequest()->getText('q'),0,200);$offset=min(100000,max(0,$this->getRequest()->getInt('offset')));
  $out->addHTML(Html::rawElement('form',['method'=>'get'],Html::input('q',$q,'search',['aria-label'=>'Find game references']).Html::element('button',['type'=>'submit'],'Find')));
  $data=$store->publicList($build,$q,$offset);foreach($data['rows'] as $r)$out->addHTML(self::card($r));
  if(!$data['rows'])$out->addHTML(Html::element('p',[],'No published references match.'));
  if($data['more'])$out->addHTML(Html::element('a',['href'=>$this->getPageTitle()->getLocalURL(['q'=>$q,'offset'=>$offset+50])],'Next'));
 }
}
