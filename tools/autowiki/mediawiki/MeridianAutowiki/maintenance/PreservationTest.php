<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use Meridian\Autowiki\{Store,Package,SearchIndex,PublicationLog,Preservation,Submission,SourceSelection};
class AutowikiPreservationTest extends Maintenance {
 private int $checks=0;
 private function check(bool $ok,string $label):void {if(!$ok)throw new RuntimeException($label);$this->checks++;$this->output("PASS $label\n");}
 private function refuses(callable $call,string $label):void {try{$call();throw new LogicException('Unexpected acceptance: '.$label);}catch(RuntimeException){$this->check(true,$label);}}
 public function execute(){
  $s=$this->getServiceContainer();$cfg=$s->getMainConfig();if($cfg->get('DBserver')!=='127.0.0.1:3307'||$cfg->get('MeridianAutowikiRequireVerifiedRelease')||$cfg->get('MeridianAutowikiSearchEnabled'))throw new RuntimeException('Isolated local fixture configuration required');
  $store=new Store();$store->install();$db=$s->getConnectionProvider()->getPrimaryDatabase();$user=$s->getUserFactory()->newFromName('Moonridden');$nonce=bin2hex(random_bytes(8));
  $record=['kind'=>'entity','id'=>'/obj/item/preservation_'.$nonce,'fields'=>['name'=>'Preservation fixture','description'=>'A test item','force'=>5,'icon_file'=>null,'documentation_visibility'=>'public']];$key=Package::recordKey($record);$hidden=$record;$hidden['id'].='_hidden';$hidden['fields']['documentation_visibility']='hidden';$hiddenKey=Package::recordKey($hidden);
  $import=function($suffix,$records)use($store,$nonce){$build=hash('sha256',$nonce.$suffix);$store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>true,'provenance'=>['dirty'=>false],'datasets'=>[['kind'=>'entity','count'=>count($records)]]],'records'=>$records]);return $build;};
  $first=$import('first',[$key=>$record,$hiddenKey=>$hidden]);
  $this->check(PublicationLog::choices($key)===[],'An imported draft is not published source evidence');
  SearchIndex::prepare($store,$first);$store->activate($first,$store->active(),$user);$pub1=PublicationLog::choices($key)[0];
  $this->check($pub1['build']===$first&&PublicationLog::choices($hiddenKey)===[],'Actual activation records only public source rows');
  $this->refuses(fn()=>$store->activate($first,str_repeat('0',64),$user),'A failed activation creates no publication event');$this->check(count(PublicationLog::choices($key))===1,'Publication history survives failed activation unchanged');
  $preparedPayload=$db->selectField('maw_public','payload',['build'=>$first,'record'=>$key],__METHOD__);$altered=json_decode($preparedPayload,true);$altered['fields']['force']=200;
  try{$db->update('maw_public',['payload'=>json_encode($altered)],['build'=>$first,'record'=>$key],__METHOD__);$this->refuses(fn()=>$store->activate($first,$first,$user),'A same-count change to prepared public values cannot enter publication history');}finally{$db->update('maw_public',['payload'=>$preparedPayload],['build'=>$first,'record'=>$key],__METHOD__);}
  $reviewDigest=$db->selectField('maw_prepared_evidence','review_digest',['build'=>$first],__METHOD__);
  try{$db->update('maw_prepared_evidence',['review_digest'=>str_repeat('0',64)],['build'=>$first],__METHOD__);$this->refuses(fn()=>$store->activate($first,$first,$user),'A matching numeric epoch cannot substitute for the exact prepared human revision digest');}finally{$db->update('maw_prepared_evidence',['review_digest'=>$reviewDigest],['build'=>$first],__METHOD__);}
  $this->check(count(PublicationLog::choices($key))===1,'Rejected source and review evidence leave publication history unchanged');
  $record['fields']['force']=8;$second=$import('second',[$key=>$record]);SearchIndex::prepare($store,$second);$store->activate($second,$first,$user);$pub2=PublicationLog::choices($key)[0];
  $this->check($pub2['build']===$second&&count(PublicationLog::choices($key))===2,'Later activation appends evidence without replacing earlier publication');
  $record['fields']['force']=9;$candidate=$import('candidate',[$key=>$record]);$preview=Preservation::preview($store,$candidate,$key,$pub1['id']);
  $this->check($preview['retained']['fields']['force']===5&&$preview['current']['fields']['force']===9,'The preservation preview compares exact published and replacement data');
  $d=['version'=>1,'target'=>$key,'type'=>'preserve','value'=>json_encode(['forBuild'=>$candidate,'publication'=>$pub1['id']]),'reason'=>'Retain the reviewed published definition for this replacement','watch'=>['preservation'],'fingerprint'=>$preview['fingerprint'],'state'=>'active'];
  $bad=$d;$bad['fingerprint']=str_repeat('0',64);$this->refuses(fn()=>Submission::prepare($store,$bad,$candidate,0),'A stale or invented preview fingerprint is refused');
  $saved=Submission::save($store,$d,$candidate,hash('sha256',$nonce.'first'),0,$user);DeferredUpdates::doUpdates();
  $this->check(Preservation::select($store,$candidate,$key)['preview']['retained']['fields']['force']===5,'A native human decision selects the published source');
  $resolved=SourceSelection::record($store,$candidate,$key);
  $this->check($resolved['fields']['force']===5&&$resolved['sourceBuild']===$first&&$resolved['sourceKey']===$key&&$resolved['sourceCommit']===str_repeat('a',40)&&$resolved['build']===$candidate,'Candidate resolution retains the original source build, identity and commit');
  $this->check($store->declaredRecord($candidate,$key)['fields']['force']===9&&$store->declaredRecord($first,$key)['fields']['force']===5,'Candidate resolution leaves both imported sources immutable');
  $this->check($resolved['preservation']['decisions'][0]['revision']===$saved['revision']&&$resolved['preservation']['publication']===$pub1['id'],'Resolved data identifies its actual publication and human revision');
  $this->check(!Preservation::applicable($store,$d,$second),'Preservation applies only to the reviewed replacement build');
  $this->refuses(fn()=>Submission::save($store,$d,$candidate,hash('sha256',$nonce.'first'),0,$user),'A stale wiki revision cannot overwrite the decision');
  $other=$d;$other['value']=json_encode(['forBuild'=>$candidate,'publication'=>$pub2['id']]);$other['fingerprint']=Preservation::preview($store,$candidate,$key,$pub2['id'])['fingerprint'];$otherSaved=Submission::save($store,$other,$candidate,hash('sha256',$nonce.'second'),0,$user);DeferredUpdates::doUpdates();
  $this->refuses(fn()=>Preservation::select($store,$candidate,$key),'Conflicting retained sources have no automatic winner');
  $this->refuses(fn()=>SourceSelection::record($store,$candidate,$key),'A conflicting candidate cannot fall back to unreviewed replacement data');
  $other['state']='revoked';Submission::save($store,$other,$candidate,hash('sha256',$nonce.'second'),$otherSaved['revision'],$user);DeferredUpdates::doUpdates();
  $this->check(Preservation::select($store,$candidate,$key)['preview']['retained']['fields']['force']===5,'Revocation restores the remaining consistent choice');
  $restriction=['version'=>1,'target'=>$key,'type'=>'visibility','value'=>'hidden','reason'=>'Restrict the current definition','watch'=>['force'],'fingerprint'=>str_repeat('0',64),'state'=>'active'];$hide=Submission::save($store,$restriction,$candidate,hash('sha256',$nonce.'hidden'),0,$user);DeferredUpdates::doUpdates();
  $this->check(!Preservation::applicable($store,$d,$candidate)&&$store->isPublic($key,$store->record($first,$key)),'A current-only visibility restriction blocks otherwise public retained data');
  $restriction['state']='revoked';Submission::save($store,$restriction,$candidate,hash('sha256',$nonce.'hidden'),$hide['revision'],$user);DeferredUpdates::doUpdates();
  $raw=$db->selectField('maw_record','fields',['build'=>$first,'id'=>$key],__METHOD__);$tampered=json_decode($raw,true);$tampered['force']=100;
  try{$db->update('maw_record',['fields'=>json_encode($tampered)],['build'=>$first,'id'=>$key],__METHOD__);$this->check(!Preservation::applicable($store,$d,$candidate),'Changed published source bytes invalidate preservation evidence');}finally{$db->update('maw_record',['fields'=>$raw],['build'=>$first,'id'=>$key],__METHOD__);}
  $this->check(Preservation::applicable($store,$d,$candidate),'Restored exact source evidence remains recognizable');
  $d['state']='revoked';Submission::save($store,$d,$candidate,hash('sha256',$nonce.'first'),$saved['revision'],$user);DeferredUpdates::doUpdates();$this->check(Preservation::select($store,$candidate,$key)===null,'Final revocation leaves no selected preservation');
  $this->check(SourceSelection::record($store,$candidate,$key)['fields']['force']===9,'Revocation returns replacement data only to the candidate resolver, pending publication checks');
  $absent=$import('absent',[]);$d['state']='active';$d['value']=json_encode(['forBuild'=>$absent,'publication'=>$pub1['id']]);$d['fingerprint']=Preservation::preview($store,$absent,$key,$pub1['id'])['fingerprint'];$missingKey=hash('sha256',$nonce.'absent');$missingSaved=Submission::save($store,$d,$absent,$missingKey,0,$user);DeferredUpdates::doUpdates();
  $this->check(SourceSelection::keys($store,$absent)===[$key]&&SourceSelection::record($store,$absent,$key)['sourceBuild']===$first,'Explicit preservation includes a missing identity in the candidate set');
  $d['state']='revoked';Submission::save($store,$d,$absent,$missingKey,$missingSaved['revision'],$user);DeferredUpdates::doUpdates();
  $this->check(SourceSelection::keys($store,$absent)===[]&&SourceSelection::record($store,$absent,$key)===null,'Revoking a missing identity removes it from the candidate set without inventing source data');
  $this->output('SUCCESS '.$this->checks." publication provenance and preservation assertions.\n");
 }
}
$maintClass=AutowikiPreservationTest::class;require RUN_MAINTENANCE_IF_MAIN;
