<?php
namespace Meridian\Autowiki;
use MediaWiki\Api\ApiBase;
final class ApiDecision extends ApiBase {
 public function isWriteMode(){return true;}
 public function needsToken(){return 'csrf';}
 public function mustBePosted(){return true;}
 public function execute():void {
  $p=$this->extractRequestParams();if(!Decisions::canReview($this->getUser()))$this->dieWithError(['meridian-autowiki-error','Human review access required'],'permissiondenied');
  try{
   $store=new Store();
   if($p['operation']==='activate'){$store->activate($p['build'],$p['expected'],$this->getUser());$result=['active'=>$p['build']];}
   elseif($p['operation']==='prepare'){
    if(!$this->getAuthority()->isAllowed('autowiki-publish'))throw new \RuntimeException('Publication permission required');
    if(!in_array($p['build'],array_column($store->builds(),'id'),true))throw new \RuntimeException('Select an imported build');
    $store->enqueue('prepare:'.$p['build'].':'.$store->epoch(),'prepare',['build'=>$p['build']]);$result=['queued'=>true];
   }elseif($p['operation']==='retry'){
    if(!$this->getAuthority()->isAllowed('autowiki-publish'))throw new \RuntimeException('Publication permission required');
    $store->retry($p['key']);$result=['queued'=>true];
   }elseif($p['operation']==='bulk'){
    if(strlen($p['payload'])>240000)throw new \RuntimeException('Bulk request too large');
    $entries=json_decode($p['payload'],true,64,JSON_THROW_ON_ERROR);
    if(!is_array($entries)||!array_is_list($entries)||count($entries)>20)throw new \RuntimeException('Select at most 20 reviewed rows');
    // Validate every envelope before making the first write. Per-row conflicts remain explicit.
    foreach($entries as $entry)if(!is_array($entry)||!isset($entry['decision'],$entry['key'],$entry['base'])||!is_array($entry['decision'])||!is_string($entry['key'])||!preg_match('/^[a-f0-9]{64}$/',$entry['key'])||!is_int($entry['base'])||$entry['base']<0)throw new \RuntimeException('Malformed bulk entry; no changes saved');
    $results=[];
    foreach($entries as $entry){
     try{$saved=Submission::save($store,$entry['decision'],$p['build'],$entry['key'],(int)$entry['base'],$this->getUser());$results[]=['key'=>$entry['key'],'ok'=>true,'revision'=>$saved['revision']];}
     catch(\RuntimeException $e){$results[]=['key'=>$entry['key'],'ok'=>false,'error'=>$e->getMessage()];}
    }
    $result=['results'=>$results];
   }else{
    if(strlen($p['payload'])>16000)throw new \RuntimeException('Decision too large');
    $d=json_decode($p['payload'],true,64,JSON_THROW_ON_ERROR);
    $result=Submission::save($store,$d,$p['build'],$p['key'],$p['base'],$this->getUser());
   }
   $this->getResult()->addValue(null,$this->getModuleName(),$result);
  }catch(\JsonException|\TypeError $e){$this->dieWithError(['meridian-autowiki-error','Malformed decision payload'],'invaliddata');}
  catch(\RuntimeException $e){$this->dieWithError(['meridian-autowiki-error',$e->getMessage()],'conflict');}
 }
 public function getAllowedParams():array {return ['operation'=>[self::PARAM_TYPE=>['save','activate','prepare','retry','bulk'],self::PARAM_DFLT=>'save'],'payload'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>''],'key'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>''],'base'=>[self::PARAM_TYPE=>'integer',self::PARAM_DFLT=>0,self::PARAM_MIN=>0],'build'=>[self::PARAM_TYPE=>'string',self::PARAM_REQUIRED=>true],'expected'=>[self::PARAM_TYPE=>'string',self::PARAM_DFLT=>'']];}
}
