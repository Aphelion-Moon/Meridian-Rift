<?php
namespace Meridian\Autowiki;
use MediaWiki\MediaWikiServices;
use RuntimeException;
/** Generated data and human decision projections deliberately have separate write paths. */
final class Store {
 private $db;
 private bool $snapshot=false;
 private array $recordCache=[],$decisionCache=[];
 private ?bool $pendingDecisions=null;
 private array $relinkCache=[];
 private ?PublicView $publicView=null;
 public function snapshot(bool $enabled):void {$this->snapshot=$enabled;$this->recordCache=[];$this->decisionCache=[];$this->pendingDecisions=null;$this->relinkCache=[];$this->publicView=null;}
 public function view(string $build):PublicView {if(!$this->publicView||$this->publicView->build!==$build)$this->publicView=new PublicView($this,$build);return $this->publicView;}
 public function publicRecord(string $build,string $key):?array {return $this->view($build)->record($key);}
 public function hasPendingDecisions(bool $fresh=false):bool {
  if(!$fresh&&$this->snapshot&&$this->pendingDecisions!==null)return $this->pendingDecisions;
  $pending=(bool)$this->db->selectField(['page','revision','d'=>'maw_decision'],'page_id',['page_namespace'=>4300,'(rev_deleted & 1) = 0','d.revision IS NULL OR d.revision <> page_latest'],__METHOD__,['LIMIT'=>1],['revision'=>['JOIN','rev_id=page_latest'],'d'=>['LEFT JOIN','d.page=page_id']]);
  if($this->snapshot)$this->pendingDecisions=$pending;return $pending;
 }
 public function requireCurrentDecisions():void {if($this->hasPendingDecisions(true))throw new RuntimeException('Editorial revisions are awaiting reconciliation; refresh the workshop after processing completes');}

 public function __construct(){ $this->db=MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase(); }
 public function install():void {Schema::install($this->db);$this->db->insert('maw_state',['name'=>'active','value'=>''],__METHOD__,['IGNORE']);foreach($this->db->select('maw_issue','*',[],__METHOD__) as $r)$this->indexIssue((array)$r);foreach($this->db->select(['maw_build','s'=>'maw_build_summary'],['maw_build.id','maw_build.manifest'],['s.build IS NULL'],__METHOD__,[],['s'=>['LEFT JOIN','s.build=maw_build.id']]) as $r){$bytes=str_starts_with($r->manifest,"\x1f\x8b")?gzdecode($r->manifest,64*1024*1024):$r->manifest;if($bytes===false)throw new RuntimeException('Invalid stored manifest');$this->summarize($r->id,json_decode($bytes,true,512,JSON_THROW_ON_ERROR));}}
 public function active():string {return (string)$this->db->selectField('maw_state','value',['name'=>'active'],__METHOD__);}
 public function canonicalKey(string $build,string $source):string {$key=$this->declaredKey($build,$source);return $this->relinks($build)[$key]??$key;}
 public function declaredKey(string $build,string $source):string {
  $exact=$this->db->selectField('maw_identity','canonical',['build'=>$build,'source'=>$source],__METHOD__);if($exact)return $exact;
  $keys=[];foreach($this->db->select('maw_identity','canonical',['source'=>$source,'canonical <> source'],__METHOD__,['DISTINCT','LIMIT'=>2]) as $row)$keys[]=$row->canonical;
  return count($keys)===1?$keys[0]:$source;
 }
 public function declaredRecord(string $build,string $key):?array {
  $key=$this->declaredKey($build,$key);$r=$this->db->selectRow('maw_record','*',['build'=>$build,'id'=>$key],__METHOD__);
  return $r?['build'=>$build,'key'=>$r->id,'kind'=>$r->kind,'id'=>$r->identity,'name'=>$r->name,'fields'=>json_decode($r->fields,true)]:null;
 }
 public function historicalRecord(string $key):?array {
  $row=$this->db->selectRow(['maw_record','b'=>'maw_build'],['build','maw_record.id'],['maw_record.id'=>array_unique([$key,$this->declaredKey('',$key)])],__METHOD__,['ORDER BY'=>['b.created DESC','b.id DESC']],['b'=>['JOIN','b.id=maw_record.build']]);return $row?$this->declaredRecord($row->build,$row->id):null;
 }
 public function relinks(string $build):array {
  if($build==='')return [];if(isset($this->relinkCache[$build]))return $this->relinkCache[$build];$this->relinkCache[$build]=[];$options=[];
  foreach($this->db->select(['maw_decision','page','revision'],'payload',['type'=>'relink','maw_decision.revision=page_latest','(rev_deleted & 1)=0'],__METHOD__,[],['page'=>['JOIN','page_id=maw_decision.page'],'revision'=>['JOIN','rev_id=page_latest']]) as $row){
   $d=json_decode($row->payload,true);if($d['state']!=='active'||$this->declaredRecord($build,$d['target']))continue;$v=Relink::value($d['value']);$old=$this->declaredRecord($v['previousBuild'],$d['target']);$candidate=$this->declaredRecord($build,$v['candidate']);
   if(!$old||!$candidate||$old['kind']!==$candidate['kind']||!Decisions::applicable($d,$candidate))continue;$options[$this->declaredKey($build,$d['target'])][$candidate['key']]=true;
  }
  foreach($options as $old=>$candidates)if(count($candidates)===1)$this->relinkCache[$build][$old]=array_key_first($candidates);return $this->relinkCache[$build];
 }
 public function state(string $key):string {return (string)$this->db->selectField('maw_state','value',['name'=>$key],__METHOD__);}
 public function epoch():int {return (int)$this->db->selectField(['page','revision'],'SUM(page_latest + rev_deleted)',['page_namespace'=>4300],__METHOD__,[],['revision'=>['JOIN','rev_id = page_latest']]);}
 public function reviewDigest():string {
  $hash=hash_init('sha256');foreach($this->db->select(['page','revision'],['page_id','page_latest','rev_deleted'],['page_namespace'=>4300],__METHOD__,['ORDER BY'=>'page_id'],['revision'=>['JOIN','rev_id=page_latest']]) as $row)hash_update($hash,json_encode((array)$row,JSON_THROW_ON_ERROR)."\n");return hash_final($hash);
 }
 public function hasBuild(string $build):bool {return (bool)$this->db->selectField('maw_build','id',['id'=>$build],__METHOD__);}
 public function publicDigest(string $build):string {
  $hash=hash_init('sha256');foreach($this->db->select('maw_public',['record','payload'],['build'=>$build],__METHOD__,['ORDER BY'=>'record']) as $row)hash_update($hash,json_encode((array)$row,JSON_THROW_ON_ERROR)."\n");return hash_final($hash);
 }
 public function prepared(string $build,string $collection,int $epoch,int $records,?string $reviewDigest=null,?string $selectionDigest=null):void {
  $reviewDigest??=$this->reviewDigest();$this->requireCurrentDecisions();if($epoch!==$this->epoch()||!hash_equals($reviewDigest,$this->reviewDigest()))throw new RuntimeException('Human revisions changed while preparing references');
  $row=['build'=>$build,'collection'=>$collection,'epoch'=>$epoch,'records'=>$records,'prepared'=>gmdate('YmdHis')];$evidence=['build'=>$build,'review_digest'=>$reviewDigest,'public_digest'=>$this->publicDigest($build),'selection_digest'=>$selectionDigest??$this->view($build)->digest()];
  $this->db->startAtomic(__METHOD__);$this->db->upsert('maw_release',$row,['build'],$row,__METHOD__);$this->db->upsert('maw_prepared_evidence',$evidence,['build'],$evidence,__METHOD__);$this->db->endAtomic(__METHOD__);
 }
 public function previousCollection(string $except):string {return (string)$this->db->selectField('maw_release','collection',['collection != '.$this->db->addQuotes(''),'collection != '.$this->db->addQuotes($except)],__METHOD__,['ORDER BY'=>'prepared DESC','LIMIT'=>1]);}
 public function refreshSearch():void {
  $this->db->startAtomic(__METHOD__,$this->db::ATOMIC_CANCELABLE);try{
   $build=$this->db->selectField('maw_state','value',['name'=>'active'],__METHOD__,['FOR UPDATE']);
   $release=$this->db->selectRow('maw_release','*',['build'=>$build],__METHOD__,['FOR UPDATE']);
   $evidence=$this->db->selectRow('maw_prepared_evidence','*',['build'=>$build],__METHOD__,['FOR UPDATE']);
   iterator_to_array($this->db->select('maw_public','record',['build'=>$build],__METHOD__,['FOR UPDATE']),false);
   iterator_to_array($this->db->select('page','page_latest',['page_namespace'=>4300],__METHOD__,['FOR UPDATE']),false);
   $this->requireCurrentDecisions();
   if(!$release||!$evidence||(int)$release->epoch!==$this->epoch()||!hash_equals($evidence->review_digest,$this->reviewDigest())||!hash_equals($evidence->public_digest,$this->publicDigest($build))||!hash_equals($evidence->selection_digest,(new PublicView($this,$build))->digest()))throw new RuntimeException('Prepared search differs from the current publication or human revisions');
   $this->installPublicProjection($build);
   $this->db->upsert('maw_state',['name'=>'search','value'=>$release->collection],['name'],['value'=>$release->collection],__METHOD__);
   $this->db->endAtomic(__METHOD__);
  }catch(\Throwable $e){$this->db->cancelAtomic(__METHOD__);throw $e;}
 }
 /** Called only inside the activation/refresh transaction after evidence checks. */
 private function installPublicProjection(string $build):void {
  foreach(['maw_public'=>'maw_live_public','maw_public_edge'=>'maw_live_edge'] as $source=>$target){
   $this->db->delete($target,['build'=>$build],__METHOD__);
   $this->db->query('INSERT INTO '.$this->db->tableName($target).' SELECT * FROM '.$this->db->tableName($source).' WHERE build = '.$this->db->addQuotes($build),__METHOD__);
  }
 }
 public function publicRecords(string $build):\Generator {
  foreach($this->db->select('maw_public','payload',['build'=>$build],__METHOD__,['ORDER BY'=>'record']) as $row)yield json_decode($row->payload,true);
 }
 public function reconcile():int {
  $count=0;$s=MediaWikiServices::getInstance();
  $hidden=$this->db->select(['maw_decision','page','revision'],['maw_decision.page','target'],['page_id IS NULL OR rev_id IS NULL OR (rev_deleted & 1) <> 0'],__METHOD__,[],['page'=>['LEFT JOIN','page_id = maw_decision.page'],'revision'=>['LEFT JOIN','rev_id = page_latest']]);
  foreach($hidden as $row){$this->db->delete('maw_decision',['page'=>$row->page],__METHOD__);$this->enqueue('unavailable:'.$row->page.':'.$this->epoch(),'refresh',['target'=>$row->target]);$count++;}
  $rows=$this->db->select(['page','maw_decision','revision'],['page_id','page_latest'],['page_namespace'=>4300,'(rev_deleted & 1) = 0','maw_decision.revision IS NULL OR maw_decision.revision <> page_latest'],__METHOD__,['LIMIT'=>200],['maw_decision'=>['LEFT JOIN','maw_decision.page = page_id'],'revision'=>['JOIN','rev_id = page_latest']]);
  foreach($rows as $row){$rev=$s->getRevisionLookup()->getRevisionById((int)$row->page_latest);$content=$rev?->getContent(\MediaWiki\Revision\SlotRecord::MAIN);
   if($rev&&!$rev->isDeleted(\MediaWiki\Revision\RevisionRecord::DELETED_TEXT)&&$content instanceof DecisionContent&&$content->isValid()){$this->projectDecision((int)$row->page_id,(int)$row->page_latest,json_decode($content->serialize(),true));$count++;}
  }return $count;
 }
 private function summarize(string $build,array $manifest):void {
  $row=['build'=>$build,'counts'=>json_encode(array_column($manifest['datasets'],'count','kind'),JSON_THROW_ON_ERROR),'ready'=>(int)($manifest['publicationReady']??false),'dirty'=>(int)($manifest['provenance']['dirty']??true)];$this->db->upsert('maw_build_summary',$row,['build'],$row,__METHOD__);
 }
 public function builds():array {
  $rows=[];foreach($this->db->select(['maw_build','s'=>'maw_build_summary'],['maw_build.id','source','created','status','counts','ready'],[],__METHOD__,['ORDER BY'=>'created DESC','LIMIT'=>30],['s'=>['JOIN','s.build=maw_build.id']]) as $r)$rows[]=['id'=>$r->id,'source'=>$r->source,'created'=>$r->created,'status'=>$r->status,'counts'=>json_decode($r->counts,true),'publicationReady'=>(bool)$r->ready];return $rows;
 }
 public function record(string $build,string $key):?array {$cacheKey=$build.':'.$key;if($this->snapshot&&array_key_exists($cacheKey,$this->recordCache))return $this->recordCache[$cacheKey];$key=$this->canonicalKey($build,$key);$r=$this->db->selectRow('maw_record','*',['build'=>$build,'id'=>$key],__METHOD__);if(!$r)return null;$record=['build'=>$build,'key'=>$r->id,'kind'=>$r->kind,'id'=>$r->identity,'name'=>$r->name,'fields'=>json_decode($r->fields,true)];$record['name']=$this->displayName($build,$record);if($this->snapshot){if(count($this->recordCache)>=3000)$this->recordCache=[];$this->recordCache[$cacheKey]=$record;}return $record;}
 private function displayName(string $build,array $r):string {
  if($r['kind']!=='reaction'||!str_starts_with($r['name'],'/'))return $r['name'];
  $names=[];foreach(array_slice($r['fields']['results']??[],0,6) as $pair){if(!is_string($pair['key']))continue;$reagent=$this->record($build,Package::key('reagent',$pair['key']));if($reagent)$names[]=$reagent['name'];}
  return ($names?implode(' + ',array_unique($names)):ucwords(str_replace('_',' ',basename($r['id'])))).' (Reaction)';
 }
 public function list(string $build,string $kind,string $query,int $offset=0):array {
  $conditions=['build'=>$build];if($kind!=='')$conditions['kind']=$kind;if($query!=='')$conditions[]='name '.$this->db->buildLike($this->db->anyString(),$query,$this->db->anyString());
  $rows=[];foreach($this->db->select('maw_record',['id','kind','identity','name'],$conditions,__METHOD__,['ORDER BY'=>['name','id'],'LIMIT'=>51,'OFFSET'=>$offset]) as $r)$rows[]=['key'=>$r->id,'kind'=>$r->kind,'id'=>$r->identity,'name'=>$r->name];return ['rows'=>array_slice($rows,0,50),'more'=>count($rows)>50];
 }
 public function decisions(string $target,?string $build=null):array {
  $build??=$this->active();$cacheKey=$build.':'.$target;if($this->snapshot&&isset($this->decisionCache[$cacheKey]))return $this->decisionCache[$cacheKey];
  $targets=[$target];foreach($this->relinks($build) as $old=>$current)if($current===$target)$targets[]=$old;
  foreach($this->db->select('maw_identity','source',['canonical'=>array_unique($targets)],__METHOD__,['DISTINCT']) as $alias)$targets[]=$alias->source;
  $rows=[];foreach($this->db->select(['maw_decision','page','revision'],'maw_decision.*',['target'=>array_unique($targets),'(rev_deleted & 1) = 0','maw_decision.revision = page_latest'],__METHOD__,['ORDER BY'=>'maw_decision.page'],['page'=>['JOIN','page_id = maw_decision.page'],'revision'=>['JOIN','rev_id = page_latest']]) as $r)$rows[]=['page'=>(int)$r->page,'revision'=>(int)$r->revision,'title'=>\MediaWiki\Title\Title::newFromID((int)$r->page)?->getPrefixedText(),'decision'=>json_decode($r->payload,true)];
  if($this->snapshot){if(count($this->decisionCache)>=10000)$this->decisionCache=[];$this->decisionCache[$cacheKey]=$rows;}return $rows;
 }
 public function projectDecision(int $page,int $revision,array $d):void {
  Decisions::validate($d);$this->db->startAtomic(__METHOD__,$this->db::ATOMIC_CANCELABLE);
  $old=$this->db->selectRow('maw_decision',['revision','payload'],['page'=>$page],__METHOD__,['FOR UPDATE']);
  if(!$old||(int)$old->revision<$revision){$row=['page'=>$page,'revision'=>$revision,'target'=>$d['target'],'type'=>$d['type'],'payload'=>json_encode($d,JSON_THROW_ON_ERROR)];$this->db->upsert('maw_decision',$row,['page'],$row,__METHOD__);$refresh=['target'=>$d['target']];if($d['type']==='relink'){$refresh['relatedTargets']=[Relink::value($d['value'])['candidate']];if($old)$refresh['relatedTargets'][]=Relink::value(json_decode($old->payload,true)['value'])['candidate'];}$this->enqueue('decision:'.$page.':'.$revision,'refresh',$refresh);$this->relinkCache=[];if($d['type']==='report'&&$d['state']==='active')$this->issue($d['target'],'reader-report:'.$page,$d['evidence']['build']??$this->active(),['page'=>$page,'reason'=>$d['value']]);}
  $this->db->endAtomic(__METHOD__);
 }
 public function enqueue(string $key,string $type,array $payload):void {$this->db->insert('maw_outbox',['id'=>hash('sha256',$key),'type'=>$type,'payload'=>json_encode($payload,JSON_THROW_ON_ERROR),'status'=>'pending','created'=>gmdate('YmdHis')],__METHOD__,['IGNORE']);$this->db->onTransactionCommitOrIdle(static fn()=>DeliveryJob::queue(),__METHOD__);}
 public function issue(string $target,string $rule,string $build,array $observation):void {
  $id=hash('sha256',$target.':'.$rule);$row=['id'=>$id,'target'=>$target,'rule'=>$rule,'first_seen'=>gmdate('YmdHis'),'last_seen'=>gmdate('YmdHis'),'build'=>$build,'observation'=>json_encode($observation,JSON_THROW_ON_ERROR)];$update=$row;unset($update['first_seen']);$this->db->upsert('maw_issue',$row,['id'],$update,__METHOD__);$this->indexIssue($row);
 }
 private function indexIssue(array $r):void {
  $observation=is_string($r['observation'])?json_decode($r['observation'],true):$r['observation'];
  $priority=str_contains($r['rule'],'conflict')||str_contains($r['rule'],'scope-change')?100:(str_starts_with($r['rule'],'reader-report')?80:($r['rule']==='legacy-image'?40:10));
  $row=['id'=>$r['id'],'fingerprint'=>Package::fingerprint(['observation'=>$observation],['observation']),'priority'=>$priority,'uses'=>max(0,(int)($observation['uses']??0))];
  $this->db->upsert('maw_issue_index',$row,['id'],$row,__METHOD__);
 }
 private function issueDecisionSql(string $type,string $fallback):string {
  $decision=$this->db->tableName('maw_decision');$page=$this->db->tableName('page');$revision=$this->db->tableName('revision');
  return "COALESCE((SELECT CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(d.payload,'$.state')) = 'active' AND JSON_UNQUOTE(JSON_EXTRACT(d.payload,'$.fingerprint')) = ".($type==='assignment'?$this->db->addQuotes(Package::fingerprint([],[])):'i.fingerprint')." THEN JSON_UNQUOTE(JSON_EXTRACT(d.payload,'$.value')) ELSE ".$this->db->addQuotes($fallback)." END FROM $decision d JOIN $page p ON p.page_id=d.page JOIN $revision r ON r.rev_id=p.page_latest WHERE d.target=maw_issue.id AND d.type=".$this->db->addQuotes($type)." AND d.revision=p.page_latest AND (r.rev_deleted & 1)=0 ORDER BY d.revision DESC LIMIT 1),".$this->db->addQuotes($fallback).")";
 }
 private function issueConditions(string $query,string $state,string $assignee):array {
  $conditions=[];$review=$this->issueDecisionSql('triage','open');$owner=$this->issueDecisionSql('assignment','');
  if($state==='attention'){$conditions[]="$review NOT IN ('resolved','dismissed')";$conditions[]="(det.state IS NULL OR det.state <> 'not-detected')";}elseif($state==='not-detected')$conditions[]="det.state = 'not-detected'";elseif($state!=='all')$conditions[]="$review = ".$this->db->addQuotes($state);
  if($assignee!=='')$conditions[]="$owner = ".$this->db->addQuotes($assignee==='unassigned'?'':$assignee);
  if($query!=='')$conditions[]=$this->db->makeList(['rule '.$this->db->buildLike($this->db->anyString(),$query,$this->db->anyString()),'observation '.$this->db->buildLike($this->db->anyString(),$query,$this->db->anyString())],LIST_OR);
  return $conditions;
 }
 public function issues(int $offset=0,string $query='',string $state='all',string $assignee=''):array {
  $review=$this->issueDecisionSql('triage','open');$owner=$this->issueDecisionSql('assignment','');$conditions=$this->issueConditions($query,$state,$assignee);
  $rows=[];foreach($this->db->select(['maw_issue','i'=>'maw_issue_index','det'=>'maw_issue_detection'],['maw_issue.*','review_state'=>$review,'assignee'=>$owner,'uses'=>'i.uses','priority'=>'i.priority'],$conditions,__METHOD__,['ORDER BY'=>['i.priority DESC','i.uses DESC','last_seen DESC','maw_issue.id'],'LIMIT'=>51,'OFFSET'=>$offset],['i'=>['LEFT JOIN','i.id=maw_issue.id'],'det'=>['LEFT JOIN','det.id=maw_issue.id']]) as $r){$item=$this->issueDetail($r->id,false);$item['review_state']=$r->review_state;$item['assignee']=$r->assignee;$item['uses']=(int)$r->uses;$item['priority']=(int)$r->priority;$rows[]=$item;}
  return ['rows'=>array_slice($rows,0,50),'more'=>count($rows)>50];
 }
 public function import(array $package):array {
  $build=$package['id'];unset($this->relinkCache[$build]);if($this->db->selectField('maw_build','id',['id'=>$build],__METHOD__)){
   $batch=[];foreach($package['records'] as $key=>$r){$batch[]=['build'=>$build,'source'=>Package::key($r['kind'],$r['id']),'canonical'=>$key];if(count($batch)>=250){$this->db->insert('maw_identity',$batch,__METHOD__,['IGNORE']);$batch=[];}}if($batch)$this->db->insert('maw_identity',$batch,__METHOD__,['IGNORE']);
   $this->scanSourceIssues($package);return ['id'=>$build,'unchanged'=>true];
  }
  $this->db->startAtomic(__METHOD__,$this->db::ATOMIC_CANCELABLE);try{
   $this->db->insert('maw_build',['id'=>$build,'source'=>$package['manifest']['source']['commit'],'created'=>gmdate('YmdHis'),'status'=>'staged','manifest'=>gzencode(json_encode($package['manifest'],JSON_THROW_ON_ERROR),6)],__METHOD__);
   $this->summarize($build,$package['manifest']);
   $batch=[];foreach($package['records'] as $key=>$r){$f=$r['fields'];$name=$f['name']??$f['display_name']??$f['title']??$r['id'];$batch[]=['build'=>$build,'id'=>$key,'kind'=>$r['kind'],'identity'=>$r['id'],'name'=>mb_strcut($name,0,512),'fields'=>json_encode($f,JSON_THROW_ON_ERROR)];if(count($batch)>=250){$this->db->insert('maw_record',$batch,__METHOD__);$batch=[];}}
   if($batch)$this->db->insert('maw_record',$batch,__METHOD__);
   $relations=Package::contract()['relations'];$batch=[];$identities=[];foreach($package['records'] as $key=>$r){$source=Package::key($r['kind'],$r['id']);$identities[$source]=$key;$batch[]=['build'=>$build,'source'=>$source,'canonical'=>$key];if(count($batch)>=250){$this->db->insert('maw_identity',$batch,__METHOD__,['IGNORE']);$batch=[];}}if($batch)$this->db->insert('maw_identity',$batch,__METHOD__,['IGNORE']);$batch=[];
   foreach($package['records'] as $key=>$r){foreach($relations[$r['kind']]??[] as $field=>$kind){$value=$r['fields'][$field]??null;$pairs=is_array($value)?$value:($value?[['key'=>$value,'value'=>null]]:[]);foreach($pairs as $pair){$identity=$pair['key'];if(!is_string($identity))continue;$target=Package::relationshipKind($kind,$identity);$sourceKey=Package::key($target,$identity);$dst=$identities[$sourceKey]??$sourceKey;$batch[]=['build'=>$build,'src'=>$key,'dst'=>$dst,'field'=>$field,'quantity'=>json_encode($pair['value'])];if(count($batch)>=250){$this->db->insert('maw_edge',$batch,__METHOD__,['IGNORE']);$batch=[];}}}
   }
   if($batch)$this->db->insert('maw_edge',$batch,__METHOD__,['IGNORE']);
   $this->scanSourceIssues($package);
   $this->db->endAtomic(__METHOD__);
  }catch(\Throwable $e){$this->db->cancelAtomic(__METHOD__);throw $e;}
  return ['id'=>$build,'records'=>count($package['records']),'status'=>'staged'];
 }
 public function scanSourceIssues(array $package):void {
  $findings=[];foreach($package['records'] as $key=>$r)if($r['kind']==='entity'&&!$r['fields']['icon_file'])$findings[]=[$key,'missing-appearance',['name'=>$r['fields']['name'],'reason'=>'No initial image; an initialized render may be required.']];
  IssueDetection::complete($this,'source-appearance',$package['id'],$findings,array_keys($package['records']));
  $this->scanDecisionIssues($package['id']);
 }
 public function scanDecisionIssues(string $build):void {
  if($this->hasPendingDecisions())return;
  $findings=[];
  foreach($this->db->select(['maw_decision','page','revision'],'maw_decision.*',['maw_decision.revision = page_latest','(rev_deleted & 1) = 0'],__METHOD__,[],['page'=>['JOIN','page_id=maw_decision.page'],'revision'=>['JOIN','rev_id=page_latest']]) as $d){
   $payload=json_decode($d->payload,true);if(in_array($payload['type'],['triage','assignment','report','preserve'],true)||$payload['state']==='revoked')continue;
   $asset=in_array($payload['type'],['asset','asset-reject'],true);$record=$this->record($build,$asset?AssetDecision::value($payload['value'])['entity']:$d->target);
   if(Decisions::applicable($payload,$record))continue;
   $fields=$record['fields']??[];
   if($asset&&$payload['watch']===['selected_profile']){$v=AssetDecision::value($payload['value']);$fields=['selected_profile'=>$record?AssetDecision::profileEvidence($fields,$v['profile']??'initial-south-first-frame'):null];}
   $watched=[];$names=$payload['watch'];sort($names);foreach($names as $name)$watched[$name]=['present'=>array_key_exists($name,$fields),'value'=>$fields[$name]??null];$preview=json_encode(Package::canonical($watched),JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR);$preview=mb_strcut($preview,0,8000).(strlen($preview)>8000?' [preview truncated]':'');
   $reason=$asset?'Reviewed image source or appearance changed':($record?'Relevant source fields changed':'Source identity absent');
   $findings[]=[$d->target,($asset?'asset-scope-change:':'decision-conflict:').$d->page,['page'=>(int)$d->page,'reason'=>$reason,'expected_fingerprint'=>$payload['fingerprint'],'source_preview'=>$preview,'source_present'=>$record!==null,'source_fingerprint'=>Package::fingerprint($fields,$payload['watch'])]];
  }
  IssueDetection::complete($this,'source-decisions',$build,$findings);
 }
 public function related(string $build,string $key):array {$rows=[];foreach($this->db->select('maw_edge','*',['build'=>$build,$this->db->makeList(['src'=>$key,'dst'=>$key],LIST_OR)],__METHOD__,['LIMIT'=>200]) as $r){$other=$this->record($build,$r->src===$key?$r->dst:$r->src);$rows[]=['direction'=>$r->src===$key?'uses':'used-by','field'=>$r->field,'quantity'=>json_decode($r->quantity,true),'record'=>$other,'missing'=>$other===null];}return $rows;}
 public function isPublic(string $key,array $record):bool {
  if($this->hasPendingDecisions())return false;
  $result=($record['fields']['documentation_visibility']??'unknown')==='public';
  $values=[];foreach($this->decisions($key,$record['build']??null) as $d)if($d['decision']['type']==='visibility'&&Decisions::applicable($d['decision'],$record))$values[]=$d['decision']['value'];
  if(in_array('hidden',$values,true))return false;return $values?in_array('public',$values,true):$result;
 }
 public function activate(string $build,string $expected,$user):void {
  $this->requireCurrentDecisions();
  $s=MediaWikiServices::getInstance();if(!Decisions::canReview($user)||!$s->getPermissionManager()->userHasRight($user,'autowiki-publish'))throw new RuntimeException('Publication permission required');
  $row=$this->db->selectRow('maw_build_summary','*',['build'=>$build],__METHOD__);$m=['publicationReady'=>(bool)($row->ready??false),'provenance'=>['dirty'=>(bool)($row->dirty??true)]];
  if(empty($m['publicationReady'])||($m['provenance']['dirty']??true)!==false)throw new RuntimeException('A clean, validated build is required for public activation');
  $approved=Release::requireVerified($build)??CandidatePlan::capture($this,$build);$candidateView=new PublicView($this,$build,$approved);
  $release=$this->db->selectRow('maw_release','*',['build'=>$build],__METHOD__);
  if(!$release||(int)$release->epoch!==$this->epoch())throw new RuntimeException('Prepare the public references and search against current human revisions first');
  foreach($this->db->select('maw_decision','payload',[],__METHOD__) as $decisionRow){$d=json_decode($decisionRow->payload,true);if($d['type']==='preserve')continue;$prior=$this->record($expected,$d['target']);if(!$prior||!$this->isPublic($d['target'],$prior))continue;$selected=$candidateView->record($d['target']);$next=$selected?$this->declaredRecord($selected['sourceBuild']??$build,$selected['sourceKey']??$selected['key']):$this->record($build,$d['target']);if($d['state']==='active'&&!in_array($d['type'],['triage','assignment','report'],true)&&!Decisions::applicable($d,$next))throw new RuntimeException('Resolve changed assumptions and absent identities before activation');}
  $reviewDigest=$this->reviewDigest();$publicDigest=$this->publicDigest($build);$sources=PublicationLog::capture($this,$build);
  $this->db->startAtomic(__METHOD__,$this->db::ATOMIC_CANCELABLE);try{
   $active=$this->db->selectField('maw_state','value',['name'=>'active'],__METHOD__,['FOR UPDATE']);if($active!==$expected)throw new RuntimeException('Active build changed; refresh the preview');
   // Lock the prepared release and decision-page range before the final freshness check.
   $release=$this->db->selectRow('maw_release','*',['build'=>$build],__METHOD__,['FOR UPDATE']);
   $evidence=$this->db->selectRow('maw_prepared_evidence','*',['build'=>$build],__METHOD__,['FOR UPDATE']);
   iterator_to_array($this->db->select('maw_public','record',['build'=>$build],__METHOD__,['FOR UPDATE']),false);
   iterator_to_array($this->db->select('page','page_latest',['page_namespace'=>4300],__METHOD__,['FOR UPDATE']),false);
   $this->requireCurrentDecisions();
   if(!$release||(int)$release->epoch!==$this->epoch())throw new RuntimeException('Human decisions changed; prepare a new publication preview');
   if(!hash_equals($reviewDigest,$this->reviewDigest())||count($sources)!==(int)$release->records)throw new RuntimeException('Prepared publication changed while source evidence was captured');
   if(!$evidence||!hash_equals($evidence->review_digest,$reviewDigest)||!hash_equals($evidence->public_digest,$publicDigest)||!hash_equals($publicDigest,$this->publicDigest($build)))throw new RuntimeException('Prepared source or review evidence changed; prepare the publication again');
   $selection=Release::requireVerified($build)??CandidatePlan::capture($this,$build);
   if(!hash_equals($evidence->selection_digest,hash('sha256',CandidatePlan::encode(CandidatePlan::snapshot($selection)))))throw new RuntimeException('Prepared references used a different source selection');
   PublicationLog::append($build,$this->epoch(),$reviewDigest,$user,$sources,$selection);
   $this->installPublicProjection($build);
   $this->db->update('maw_state',['value'=>$build],['name'=>'active'],__METHOD__);
   $this->publicView=null;
   $this->db->upsert('maw_state',['name'=>'search','value'=>$release->collection],['name'],['value'=>$release->collection],__METHOD__);
   $this->enqueue('activate:'.$build.':'.bin2hex(random_bytes(8)),'activate',['build'=>$build,'previous'=>$active,'user'=>$user->getName()]);$this->db->endAtomic(__METHOD__);
  }catch(\Throwable $e){$this->db->cancelAtomic(__METHOD__);throw $e;}
 }
 public function dependency(int $page,string $key,string $field):void {if($page>0)$this->db->insert('maw_dependency',['page'=>$page,'target'=>$key,'field'=>$field],__METHOD__,['IGNORE']);}
 public function replaceDependencies(int $page,array $dependencies):void {
  if(!$page)return;$this->db->startAtomic(__METHOD__);$this->db->delete('maw_dependency',['page'=>$page],__METHOD__);$this->db->delete('maw_guide_anchor',['page'=>$page],__METHOD__);$this->db->delete('maw_guide_use',['page'=>$page],__METHOD__);
  foreach($dependencies as $d){$this->dependency($page,$d['key'],$d['field']);$this->db->insert('maw_guide_use',['page'=>$page,'target'=>$d['key'],'field'=>$d['field'],'anchor'=>$d['anchor']??''],__METHOD__,['IGNORE']);}$this->db->endAtomic(__METHOD__);
 }
 public function pending():array {return iterator_to_array($this->db->select('maw_outbox','*',['status'=>'pending'],__METHOD__,['ORDER BY'=>'created','LIMIT'=>100]),false);}
 /** Aggregate the whole queue: old failures must not vanish behind recent successes. */
 public function deliveryHealth():array {
  $counts=['pending'=>0,'failed'=>0,'done'=>0];$oldest=null;
  foreach($this->db->select('maw_outbox',['status','total'=>'COUNT(*)','oldest'=>'MIN(created)'],[],__METHOD__,['GROUP BY'=>'status']) as $row){
   if(array_key_exists($row->status,$counts))$counts[$row->status]=(int)$row->total;
   if($row->status==='pending')$oldest=(string)$row->oldest;
  }
  return ['counts'=>$counts,'oldestPending'=>$oldest];
 }
 public function deliveries():array {return iterator_to_array($this->db->select('maw_outbox',['id','type','status','attempts','error','created'],[],__METHOD__,['ORDER BY'=>"CASE status WHEN 'failed' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END, created ASC, id ASC",'LIMIT'=>100]),false);}
 public function publicList(string $build,string $query,int $offset=0):array {
  $conditions=['build'=>$build];if($query!=='')$conditions[]='name '.$this->db->buildLike($this->db->anyString(),$query,$this->db->anyString());
  $rows=[];$page=$this->db->select('maw_live_public','record',$conditions,__METHOD__,['ORDER BY'=>['name','record'],'LIMIT'=>51,'OFFSET'=>$offset]);$seen=0;foreach($page as $r){$seen++;if($seen>50)break;$record=$this->publicRecord($build,$r->record);if($record)$rows[]=$record;}
  return ['rows'=>array_slice($rows,0,50),'more'=>$seen>50];
 }
 public function derive(string $build,?string $key=null,?array $selection=null):int {
  $this->requireCurrentDecisions();$digest=$this->reviewDigest();$this->publicView=new PublicView($this,$build,$selection);$view=$this->publicView;$records=[];$edges=[];
  foreach($key?[$this->canonicalKey($build,$key)]:$view->keys() as $id){$r=$view->record($id);if(!$r)continue;$records[]=['build'=>$build,'record'=>$r['key'],'name'=>mb_strcut($r['name'],0,512),'kind'=>$r['kind'],'family'=>$r['family']??$r['key'],'payload'=>json_encode($r,JSON_THROW_ON_ERROR)];array_push($edges,...$view->edges($r));}
  $this->requireCurrentDecisions();if(!hash_equals($digest,$this->reviewDigest()))throw new RuntimeException('Human decisions changed while deriving public references');
  $this->db->startAtomic(__METHOD__,$this->db::ATOMIC_CANCELABLE);try{
   $conditions=['build'=>$build];$edgeConditions=$conditions;if($key){$conditions['record']=$this->canonicalKey($build,$key);$edgeConditions['src']=$conditions['record'];}
   $this->db->delete('maw_public',$conditions,__METHOD__);$this->db->delete('maw_public_edge',$edgeConditions,__METHOD__);
   foreach(array_chunk($records,250) as $batch)$this->db->insert('maw_public',$batch,__METHOD__);
   foreach(array_chunk($edges,250) as $batch)$this->db->insert('maw_public_edge',$batch,__METHOD__,['IGNORE']);$this->db->endAtomic(__METHOD__);
  }catch(\Throwable $e){$this->db->cancelAtomic(__METHOD__);throw $e;}return count($records);
 }
 public function getIssue(string $id):?array {
  $row=$this->db->selectRow('maw_issue','*',['id'=>$id],__METHOD__);
  if(!$row)return null;$item=(array)$row;$item['observation']=json_decode($row->observation,true);return $item;
 }
 public function issueDetail(string $id,bool $history=true,int $offset=0):?array {
  $item=$this->getIssue($id);if(!$item)return null;$item['detection']=IssueDetection::detail($id,$history,$offset);$item['fingerprint']=Package::fingerprint(['observation'=>$item['observation']],['observation']);$item['decisions']=$this->decisions($id,$item['build']);
  foreach($item['decisions'] as &$row){$d=$row['decision'];$record=in_array($d['type'],['asset','asset-reject'],true)?$this->record($item['build'],AssetDecision::value($d['value'])['entity']):['fields'=>['observation'=>$item['observation']]];$row['applicable']=Decisions::applicable($d,$record);}unset($row);return $item;
 }
 public function issueGroups(string $query='',string $state='all',string $assignee=''):array {
  $rows=[];foreach($this->db->select(['maw_issue','i'=>'maw_issue_index','det'=>'maw_issue_detection'],['rule'=>"SUBSTRING_INDEX(rule,':',1)",'COUNT(*) AS count'],$this->issueConditions($query,$state,$assignee),__METHOD__,['GROUP BY'=>"SUBSTRING_INDEX(rule,':',1)",'ORDER BY'=>'count DESC','LIMIT'=>100],['i'=>['LEFT JOIN','i.id=maw_issue.id'],'det'=>['LEFT JOIN','det.id=maw_issue.id']]) as $r)$rows[]=(array)$r;return $rows;
 }
 public function editorial(string $query,int $offset):array {
  $conditions=['(rev_deleted & 1) = 0','maw_decision.revision = page_latest'];if($query!=='')$conditions[]='payload '.$this->db->buildLike($this->db->anyString(),$query,$this->db->anyString());
  $rows=[];foreach($this->db->select(['maw_decision','page','revision'],'maw_decision.*',$conditions,__METHOD__,['ORDER BY'=>'maw_decision.revision DESC','LIMIT'=>51,'OFFSET'=>$offset],['page'=>['JOIN','page_id = maw_decision.page'],'revision'=>['JOIN','rev_id = page_latest']]) as $row){
   $d=json_decode($row->payload,true);$record=$this->record($this->active(),$d['target']);
   $rows[]=['page'=>(int)$row->page,'revision'=>(int)$row->revision,'title'=>\MediaWiki\Title\Title::newFromID((int)$row->page)?->getPrefixedText(),'decision'=>$d,'applicable'=>Decisions::applicable($d,$record)];
  }return ['rows'=>array_slice($rows,0,50),'more'=>count($rows)>50];
 }
 public function guideImpact(string $key='',?string $build=null):array {
  $conditions=[];if($key){$build??=$this->active();$targets=[$key,$this->canonicalKey($build,$key)];foreach($this->relinks($build) as $old=>$current)if(in_array($current,$targets,true))$targets[]=$old;foreach($this->db->select('maw_identity','source',['canonical'=>array_unique($targets)],__METHOD__,['DISTINCT']) as $alias)$targets[]=$alias->source;$conditions=['target'=>array_unique($targets)];}
  $rows=[];foreach($this->db->select('maw_guide_use','*',$conditions,__METHOD__,['ORDER BY'=>['page','target','field','anchor'],'LIMIT'=>200]) as $r){$title=\MediaWiki\Title\Title::newFromID((int)$r->page);if($title)$rows[]=['page'=>$title->getPrefixedText(),'url'=>$title->getLocalURL().($r->anchor?'#'.rawurlencode($r->anchor):''),'target'=>$r->target,'field'=>$r->field,'anchor'=>$r->anchor];}return $rows;
 }
 public function retry(string $id):void {$this->db->update('maw_outbox',['status'=>'pending','error'=>''],['id'=>$id,'status'=>'failed'],__METHOD__);$this->db->onTransactionCommitOrIdle(static fn()=>DeliveryJob::queue(),__METHOD__);}
 /** Workers serialize with a filesystem lock; DB changes and purges can safely repeat after a crash. */
 public function drain(callable $deliver,int $limit=100):array {
  $done=0;$failed=0;
  foreach(array_slice($this->pending(),0,$limit) as $event){
   try{$deliver($event->type,json_decode($event->payload,true));$this->db->update('maw_outbox',['status'=>'done','error'=>'','attempts'=>(int)$event->attempts+1],['id'=>$event->id],__METHOD__);$done++;}
   catch(\Throwable $e){$this->db->update('maw_outbox',['status'=>'failed','error'=>'Delivery failed; inspect the private worker log and retry.','attempts'=>(int)$event->attempts+1],['id'=>$event->id],__METHOD__);wfDebugLog('MeridianAutowiki',get_class($e).': '.$e->getMessage());$failed++;}
  }return ['done'=>$done,'failed'=>$failed];
 }
 public function purge(array $payload):void {
  $s=MediaWikiServices::getInstance();$conditions=[];
  if(isset($payload['target'])){$targets=array_merge([$payload['target']],$payload['relatedTargets']??[]);$targets[]=$this->canonicalKey($this->active(),$payload['target']);foreach($this->relinks($this->active()) as $old=>$current)if(in_array($old,$targets,true)||in_array($current,$targets,true)){$targets[]=$old;$targets[]=$current;}foreach($this->db->select('maw_identity','source',['canonical'=>array_unique($targets)],__METHOD__,['DISTINCT']) as $r)$targets[]=$r->source;$conditions=['target'=>array_unique($targets)];}
  $pages=$this->db->select('maw_dependency',['page'],$conditions,__METHOD__,['DISTINCT']);
  foreach($pages as $row){$title=\MediaWiki\Title\Title::newFromID((int)$row->page);if($title)$s->getWikiPageFactory()->newFromTitle($title)->doPurge();}
 }
}
