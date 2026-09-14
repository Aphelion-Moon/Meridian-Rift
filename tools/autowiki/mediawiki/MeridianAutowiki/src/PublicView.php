<?php
namespace Meridian\Autowiki;

use MediaWiki\MediaWikiServices;
use RuntimeException;

/** One approved source choice for public records, relationships and appearances. */
final class PublicView {
 private array $selection,$replacements=[],$corrections=[],$members=[];
 private bool $candidate;
 private bool $available=true;
 public function __construct(private Store $store,public readonly string $build,?array $selection=null){
  $this->candidate=$selection!==null;
  if($selection!==null){if($selection['build']!==$build)throw new RuntimeException('Selection belongs to another build');$this->selection=CandidatePlan::snapshot($selection);}
  else{
   $publication=$build===$store->active()?PublicationLog::latest($build):null;
   $this->selection=['build'=>$build,'replacements'=>[],'corrections'=>[]];$this->available=$publication!==null;
   if($publication){try{$this->selection=CandidatePlan::previous($build,$publication['id']);}catch(RuntimeException|\JsonException){$this->available=false;wfDebugLog('MeridianAutowiki','Published source selection is unavailable.');}
    if($this->available){$db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();foreach($db->select('maw_published_source','*',['publication'=>$publication['id']],__METHOD__) as $row)$this->members[$row->record]=(array)$row;}}
  }
  foreach($this->selection['replacements'] as $r)$this->replacements[$r['key']]=$r;
  foreach($this->selection['corrections'] as $r)$this->corrections[$r['key']]=$r['fields'];
 }
 public function digest():string {return hash('sha256',CandidatePlan::encode($this->selection));}
 public function keys():array {return $this->candidate?SourceSelection::keys($this->store,$this->build):array_keys($this->members);}
 private function unavailable(string $message):?array {if($this->candidate)throw new RuntimeException($message);return null;}
 public function record(string $key):?array {
  $key=$this->store->canonicalKey($this->build,$key);if(!$this->available||(!$this->candidate&&!isset($this->members[$key])))return null;
  try{$r=SourceSelection::record($this->store,$this->build,$key);}catch(RuntimeException $e){return $this->unavailable($e->getMessage());}
  $expected=$this->replacements[$key]??null;
  if(!$r)return $expected?$this->unavailable('The approved retained source is no longer eligible'):null;
  if(isset($r['preservation'])!==($expected!==null))return $this->unavailable('The source choice requires publication review');
  if($expected){
   $decisions=array_map(static fn($d)=>['page'=>$d['page'],'revision'=>$d['revision']],$r['preservation']['decisions']);
   if($r['sourceBuild']!==$expected['sourceBuild']||$r['sourceKey']!==$expected['sourceKey']||$r['preservation']['publication']!==$expected['publication']||CandidatePlan::encode($decisions)!==CandidatePlan::encode($expected['decisions']))return $this->unavailable('The retained source decision changed after approval');
  }
  $corrections=[];foreach($r['editorial'] as $field=>$evidence)$corrections[$field]=$r['fields'][$field];
  if(CandidatePlan::encode($corrections)!==CandidatePlan::encode($this->corrections[$key]??[]))return $this->unavailable('Changed factual corrections require publication review');
  if(!$this->candidate){$source=$this->members[$key];$raw=$this->store->declaredRecord($source['source_build'],$source['source_record']);if(!$raw||($r['sourceBuild']??$this->build)!==$source['source_build']||($r['sourceKey']??$key)!==$source['source_record']||!hash_equals($source['fingerprint'],PublicationLog::fingerprint($raw)))return null;}
  return $r;
 }
 /** A reviewed native filename mapping also authorizes images of uncatalogued records. */
 public function mappingRecord(string $key):?array {
  if($this->store->hasPendingDecisions(true))return null;
  $key=$this->store->canonicalKey($this->build,$key);$r=$this->record($key);if($r)return $r;
  if(!$this->available||isset($this->members[$key])||isset($this->replacements[$key]))return null;
  try{if(Preservation::select($this->store,$this->build,$key))return null;}catch(RuntimeException){return null;}
  $r=$this->store->record($this->build,$key);if(!$r||($r['fields']['documentation_visibility']??'')==='hidden')return null;
  foreach($this->store->decisions($key,$this->build) as $row){$d=$row['decision'];if($d['type']==='visibility'&&$d['value']==='hidden'&&Decisions::applicable($d,$r))return null;}
  return $r;
 }
 public function asset(string $key,string $profile='initial-south-first-frame'):?array {
  $r=$this->record($key);return $r?Assets::get($r['sourceBuild']??$this->build,$r['sourceKey']??$r['key'],$profile):null;
 }
 /** Outgoing edges are reconstructed from exactly the approved fields. */
 public function edges(array $r):array {
  $edges=[];
  foreach(Package::contract()['relations'][$r['kind']]??[] as $field=>$kind){$value=$r['fields'][$field]??null;$pairs=is_array($value)?$value:($value?[['key'=>$value,'value'=>null]]:[]);
   foreach($pairs as $pair){if(!is_string($pair['key']))continue;$target=Package::relationshipKind($kind,$pair['key']);$dst=$this->store->canonicalKey($this->build,Package::key($target,$pair['key']));$edges[]=['build'=>$this->build,'src'=>$r['key'],'dst'=>$dst,'field'=>$field,'quantity'=>json_encode($pair['value'],JSON_THROW_ON_ERROR)];}
  }return $edges;
 }
 public function related(string $key):array {
  $r=$this->record($key);if(!$r)return [];$key=$r['key'];$rows=[];
  foreach($this->edges($r) as $e){$other=$this->record($e['dst']);if($other)$rows[]=['direction'=>'uses','field'=>$e['field'],'quantity'=>json_decode($e['quantity'],true),'record'=>$other,'missing'=>false];}
  $db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();
  foreach($db->select($this->candidate?'maw_public_edge':'maw_live_edge','*',['build'=>$this->build,'dst'=>$key],__METHOD__,['LIMIT'=>200]) as $edge){$other=$this->record($edge->src);if(!$other)continue;
   foreach($this->edges($other) as $actual)if($actual['dst']===$key&&$actual['field']===$edge->field)$rows[]=['direction'=>'used-by','field'=>$actual['field'],'quantity'=>json_decode($actual['quantity'],true),'record'=>$other,'missing'=>false];
  }return array_slice($rows,0,200);
 }
}
