<?php
namespace Meridian\Autowiki;
use MediaWiki\Api\ApiBase;
final class ApiData extends ApiBase {
 public function execute():void {
  $p=$this->extractRequestParams();$p['query']=mb_substr($p['query'],0,200);$review=Decisions::canReview($this->getUser());$store=new Store();$build=$p['build']?:$store->active();
  if(!$review&&($p['view']!=='records'||$build!==$store->active()))$this->dieWithError(['meridian-autowiki-error','Review access required'],'permissiondenied');
  if($build!==''&&!preg_match('/^[a-f0-9]{64}$/',$build))$this->dieWithError(['meridian-autowiki-error','Invalid build'],'badbuild');
  $data=match($p['view']){
   'status'=>['operations'=>Operations::read($store),'editorialPending'=>$store->hasPendingDecisions(),'deployment'=>DeploymentStatus::read(),'active'=>$store->active(),'builds'=>$store->builds(),'outbox'=>array_map(static fn($r)=>(array)$r,$store->deliveries()),'canPublish'=>$this->getAuthority()->isAllowed('autowiki-publish')],
   'issues'=>$p['key']!==''?['issue'=>$store->issueDetail($p['key'],true,$p['offset'])]:$store->issues($p['offset'],$p['query'],$p['reviewstate'],$p['assignee']==='me'?$this->getUser()->getName():$p['assignee'])+['groups'=>$store->issueGroups($p['query'],$p['reviewstate'],$p['assignee']==='me'?$this->getUser()->getName():$p['assignee'])],
   'decisions'=>$store->editorial($p['query'],$p['offset']),
   'publication'=>GateReview::findings($build,$p['offset'],$p['query']),
   'preservation'=>$this->preservation($store,$build,$p['key'],$p['publication'],$p['offset']),
   'guides'=>['rows'=>$store->guideImpact($p['key']),'more'=>false],
   default=>$p['key']!==''?$this->detail($store,$build,$p['key'],$review):($review?$store->list($build,$p['kind'],$p['query'],$p['offset']):$store->publicList($build,$p['query'],$p['offset']))
  };
  $this->getResult()->addValue(null,$this->getModuleName(),$data);
 }
 private function preservation(Store $store,string $build,string $key,string $publication,int $offset):array {
  if(!preg_match('/^[a-f0-9]{64}$/',$key))$this->dieWithError(['meridian-autowiki-error','Select a record identity'],'badidentity');
  if($publication===''){$rows=PublicationLog::choices($key,$offset);return ['rows'=>array_slice($rows,0,50),'more'=>count($rows)>50];}
  if(!preg_match('/^[a-f0-9]{64}$/',$publication))$this->dieWithError(['meridian-autowiki-error','Select a publication'],'badpublication');
  try{return ['eligible'=>true]+Preservation::preview($store,$build,$key,$publication);}catch(\RuntimeException $e){return ['eligible'=>false,'message'=>$e->getMessage()];}
 }
 private function detail(Store $store,string $build,string $key,bool $review):array {
  if(!preg_match('/^[a-f0-9]{64}$/',$key))$this->dieWithError(['meridian-autowiki-error','Invalid identity'],'badidentity');$r=$review?$store->record($build,$key):$store->publicRecord($build,$key);
  if(!$r)return ['missing'=>true,'historical'=>$review?$store->historicalRecord($key):null,'decisions'=>$review?$store->decisions($key,$build):[]];
  $key=$r['key'];$decisions=$store->decisions($key,$build);foreach($decisions as &$d){$d['applicable']=$d['decision']['type']==='preserve'?Preservation::applicable($store,$d['decision'],$build):Decisions::applicable($d['decision'],$r);$d['title']=\MediaWiki\Title\Title::newFromID($d['page'])?->getPrefixedText();if($review&&$d['decision']['type']!=='preserve'&&!$d['applicable']&&isset($d['decision']['evidence']['build'])){$prior=$store->record($d['decision']['evidence']['build'],$key);$d['comparison']=[];foreach($d['decision']['watch'] as $field)$d['comparison'][]=['field'=>$field,'reviewed'=>$prior['fields'][$field]??null,'current'=>$r['fields'][$field]??null];}}unset($d);
  $related=$review?$store->related($build,$key):$store->view($build)->related($key);
  $r['build']=$build;
  $sourceBuild=$r['sourceBuild']??$build;$sourceKey=$r['sourceKey']??$key;$query=$review?['review'=>1]:[];
  $images=[];foreach(Package::contract()['renderProfiles'] as $profile=>$label)if(Assets::get($sourceBuild,$sourceKey,$profile))$images[]=['profile'=>$profile,'label'=>$label,'url'=>\MediaWiki\SpecialPage\SpecialPage::getTitleFor('AutowikiImage',$build.'/'.$key.'/'.$profile)->getLocalURL($query),'scope'=>Package::profiles($r)[$profile]['scope']??$r['fields']['appearance_scope']??''];
  return ['images'=>$images,'record'=>$r,'effective'=>$review?Effective::record($r,$decisions):$r,'image'=>Assets::get($sourceBuild,$sourceKey)?\MediaWiki\SpecialPage\SpecialPage::getTitleFor('AutowikiImage',$build.'/'.$key)->getLocalURL($query):null,'decisions'=>$review?$decisions:array_values(array_filter($decisions,fn($d)=>$d['applicable']&&in_array($d['decision']['type'],['annotation','alias'],true))),'related'=>$related,'units'=>Package::contract()['units'],'guides'=>$store->guideImpact($key,$build)];
 }
 public function getAllowedParams():array {return ['reviewstate'=>[self::PARAM_TYPE=>['all','attention','open','acknowledged','resolved','dismissed','not-detected'],self::PARAM_DFLT=>'all'],'assignee'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>''],'view'=>[self::PARAM_TYPE=>['status','records','issues','decisions','guides','publication','preservation'],self::PARAM_DFLT=>'records'],'build'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>''],'key'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>''],'publication'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>''],'kind'=>[self::PARAM_TYPE=>array_merge([''],array_keys(Package::contract()['fields'])),self::PARAM_DFLT=>''],'query'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>''],'offset'=>[self::PARAM_TYPE=>'integer',self::PARAM_DFLT=>0,self::PARAM_MIN=>0,self::PARAM_MAX=>2000000]];}
}
