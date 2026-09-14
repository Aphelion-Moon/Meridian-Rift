<?php
namespace Meridian\Autowiki;
use RuntimeException;
final class Delivery {
 public static function run():array {
  $lock=fopen(Assets::root().'/worker.lock','c');if(!$lock||!flock($lock,LOCK_EX|LOCK_NB))return ['done'=>0,'failed'=>0,'busy'=>true];
  try{
   $store=new Store();$store->reconcile();$preparedBuild='';$failure=null;
   return $store->drain(static function($type,$payload)use($store,&$preparedBuild,&$failure){
    if($type==='prepare'){SearchIndex::prepare($store,$payload['build']);return;}
    if(!in_array($type,['refresh','activate'],true))throw new RuntimeException('Unknown delivery type');
    // Withdraw cached facts even when search or image delivery is unavailable.
    $store->purge($payload);if($store->active())$store->scanDecisionIssues($store->active());if($failure)throw $failure;
    if($store->active()&&$preparedBuild!==$store->active()){
     try{SearchIndex::prepare($store,$store->active(),false);$store->refreshSearch();AssetPublisher::publish($store);$preparedBuild=$store->active();}
     catch(\Throwable $e){$failure=$e;throw $e;}
    }
   });
  }finally{flock($lock,LOCK_UN);fclose($lock);}
 }
}
