<?php
namespace Meridian\Autowiki;

use MediaWiki\MediaWikiServices;
use MediaWiki\Config\MultiConfig;
use MediaWiki\Config\HashConfig;
use MediaWiki\SpecialPage\SpecialPage;
use Meridian\Search\Client;
use RuntimeException;

/** Prepared physical collections are selected through the wiki's active release state. */
final class SearchIndex {
 public static function enabled(): bool {
  return MediaWikiServices::getInstance()->getMainConfig()->get('MeridianAutowikiSearchEnabled') && class_exists(Client::class);
 }
 private static function client(bool $write=false): Client {
  $config=MediaWikiServices::getInstance()->getMainConfig();
  if(!$write)$config=new MultiConfig([new HashConfig(['MeridianSearchKeyFile'=>$config->get('MeridianAutowikiSearchKeyFile')]),$config]);
  return new Client($config,$write);
 }
 public static function digest(array $record): string {
  return hash('sha256',json_encode(Package::canonical($record),JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR));
 }
 private static function document(array $r,Store $store):array {
  $parts=[];foreach($r['fields'] as $name=>$value){
   if(in_array($name,['parent','icon_source','icon_file','icon_state','documentation_id','documentation_family','deferred_fields','render_profiles'],true))continue;
   $parts[]=str_replace('_',' ',$name).': '.strip_tags(Reference::value($value));
  }
  foreach($r['annotations'] as $note)$parts[]=$note;
  foreach($store->view($r['build'])->related($r['key']) as $e)$parts[]=str_replace('_',' ',$e['field']).': '.$e['record']['name'];
  if(isset($r['preservation']))$parts[]='Retained documentation from an earlier build: '.$r['sourceBuild'];
  $body=mb_substr(implode("\n",$parts),0,12000);return ['id'=>$r['key'],'name'=>$r['name'],'body'=>$body,'kind'=>$r['kind'],'family'=>$r['family']??$r['key'],'build'=>$r['build'],'digest'=>self::digest(['record'=>$r,'body'=>$body])];
 }
 public static function prepare(Store $store,string $build,bool $publication=true):array {
  if(!preg_match('/^[a-f0-9]{64}$/',$build))throw new RuntimeException('Invalid build');
  $store->reconcile();$store->requireCurrentDecisions();
  if(!$publication&&$build!==$store->active())throw new RuntimeException('Only the active publication can be refreshed');
  $selection=$publication?(Release::requireVerified($build)??CandidatePlan::capture($store,$build)):null;
  $epoch=$store->epoch();$reviewDigest=$store->reviewDigest();$store->snapshot(true);try{$store->derive($build,null,$selection);$selectionDigest=$store->view($build)->digest();$documents=[];
  foreach($store->publicRecords($build) as $r)$documents[]=self::document($r,$store);
  $model=self::enabled()?MediaWikiServices::getInstance()->getMainConfig()->get('MeridianSearchModel'):'disabled';$reused=0;
  $generation=hash('sha256',json_encode([$build,$model,array_map(static fn($d)=>hash('sha256',json_encode($d,JSON_THROW_ON_ERROR)),$documents)],JSON_THROW_ON_ERROR));
  $collection='meridian_game_'.substr($build,0,12).'_'.substr($generation,0,16);
  if(self::enabled()){
   $client=self::client(true);$exists=false;
   try{$metadata=$client->request('GET','collections/'.$collection);$exists=true;}catch(RuntimeException $e){if(!str_contains($e->getMessage(),'HTTP 404'))throw $e;}
   if(!$exists){
    $fields=[];foreach(['name','body','build','digest'] as $field)$fields[]=['name'=>$field,'type'=>'string'];
    foreach(['kind','family'] as $field)$fields[]=['name'=>$field,'type'=>'string','facet'=>true];
    $fields[]=['name'=>'embedding','type'=>'float[]','embed'=>['from'=>['name','body'],'model_config'=>['model_name'=>MediaWikiServices::getInstance()->getMainConfig()->get('MeridianSearchModel')]]];
    $metadata=$client->request('POST','collections',body:['name'=>$collection,'fields'=>$fields],timeout:120);
   }
   if(!$exists||(int)($metadata['num_documents']??0)!==count($documents)){
    $prior=$store->previousCollection($collection);$source=null;
    if($prior)try{$candidate=$client->request('GET','collections/'.$prior);$a=array_values(array_filter($candidate['fields']??[],static fn($f)=>$f['name']==='embedding'))[0]??null;$b=array_values(array_filter($metadata['fields']??[],static fn($f)=>$f['name']==='embedding'))[0]??null;if($a&&$b&&$a['embed']===$b['embed']&&$a['num_dim']===$b['num_dim'])$source=['name'=>$prior,'dimensions'=>$a['num_dim']];}catch(RuntimeException){/* Rebuild normally if an older index is unavailable. */}
    foreach(array_chunk($documents,50) as $batch){
     if($source){$vectors=[];try{$response=$client->request('GET','collections/'.$source['name'].'/documents/search',['q'=>'*','query_by'=>'name','filter_by'=>'id:=['.implode(',',array_column($batch,'id')).']','per_page'=>50,'include_fields'=>'name,body,embedding']);foreach($response['hits']??[] as $hit){$d=$hit['document'];if(isset($d['embedding'])&&count($d['embedding'])===$source['dimensions'])$vectors[hash('sha256',$d['name']."\0".$d['body'])]=$d['embedding'];}foreach($batch as &$d){$key=hash('sha256',$d['name']."\0".$d['body']);if(isset($vectors[$key])){$d['embedding']=$vectors[$key];$reused++;}}unset($d);}catch(RuntimeException){/* An unavailable cache is not missing source data. */}}
     $client->request('POST','collections/'.$collection.'/documents/import',['action'=>'upsert'],implode("\n",array_map(static fn($d)=>json_encode($d,JSON_THROW_ON_ERROR),$batch)),true,120);
    }
   }
   $metadata=$client->request('GET','collections/'.$collection);
   if((int)$metadata['num_documents']!==count($documents))throw new RuntimeException('Prepared search count differs from the public reference');
  }else $collection='';
  $store->requireCurrentDecisions();if($store->epoch()!==$epoch||!hash_equals($reviewDigest,$store->reviewDigest()))throw new RuntimeException('Human decisions changed during preparation; retry against their new revisions');
  $store->prepared($build,$collection,$epoch,count($documents),$reviewDigest,$selectionDigest);
  return ['build'=>$build,'collection'=>$collection,'documents'=>count($documents),'epoch'=>$epoch,'reusedEmbeddings'=>$reused];}finally{$store->snapshot(false);}
 }
 public static function search(string $query,int $limit=20):array {
  $store=new Store();$build=$store->active();$collection=$store->state('search');
  if(!$build||!$collection||!self::enabled())return [];
  $query=mb_substr(trim($query),0,250);if($query==='')return [];
  $response=self::client()->request('GET','collections/'.rawurlencode($collection).'/documents/search',[
   'q'=>$query,'query_by'=>'name,body,embedding','query_by_weights'=>'4,1,1','group_by'=>'family','group_limit'=>1,'per_page'=>min(50,max(1,$limit)),
   'exclude_fields'=>'embedding','highlight_fields'=>'none','vector_query'=>'embedding:([],alpha:0.7,k:100)',
  ]);
  $results=[];foreach($response['grouped_hits']??[] as $group){
   $doc=$group['hits'][0]['document']??null;if(!$doc||$doc['build']!==$build)continue;
   $r=$store->publicRecord($build,$doc['id']);if(!$r)continue;
   if(!hash_equals($doc['digest'],self::document($r,$store)['digest']))continue;
   $results[]=['id'=>'game:'.$r['key'],'pageid'=>0,'title'=>$r['name'],'heading'=>'Game Reference','anchor'=>'','snippet'=>mb_strimwidth($doc['body'],0,380,'…'),'url'=>SpecialPage::getTitleFor('GameReference',$r['key'])->getLocalURL(),'kind'=>'game-reference','department'=>$r['kind']];
  }return $results;
 }
}
