<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Deferred\DeferredUpdates;
use MediaWiki\Context\RequestContext;
use MediaWiki\Request\FauxRequest;
use MediaWiki\Api\ApiMain;
use Meridian\Autowiki\{Store,Package,Assets,SearchIndex,PublicationLog,Preservation,Submission,Reference,Image};
class AutowikiPublicViewTest extends Maintenance {
 private int $checks=0;
 private function check(bool $ok,string $label):void{if(!$ok)throw new RuntimeException($label);$this->checks++;$this->output("PASS $label\n");}
 private function context($user,array $params=[]):RequestContext{$c=new RequestContext();$c->setUser($user);$c->setRequest(new FauxRequest($params));$c->setTitle(MediaWiki\Title\Title::newFromText('Special:GameReference'));return $c;}
 private function api($user,string $key):array{$main=new ApiMain($this->context($user,['action'=>'autowikidata','key'=>$key,'format'=>'json','formatversion'=>2]),true);$main->execute();return $main->getResult()->getResultData(null,['Strip'=>'all'])['autowikidata'];}
 private function image($user,string $build,string $key,bool $review=false):array{$ctx=$this->context($user,['review'=>$review?1:0]);$page=new Image();$page->setContext($ctx);ob_start();try{$page->execute($build.'/'.$key);$bytes=ob_get_contents();}finally{ob_end_clean();}return ['bytes'=>$bytes,'status'=>$ctx->getRequest()->response()->getStatusCode(),'cache'=>$ctx->getRequest()->response()->getHeader('Cache-Control')];}
 private function fields(string $kind):array{$f=[];foreach(Package::contract()['fields'][$kind] as $name=>$types)$f[$name]=in_array('array',$types,true)?[]:(in_array('number',$types,true)?0:(in_array('null',$types,true)?null:'fixture'));$f['documentation_visibility']='public';return $f;}
 public function execute(){
  $s=$this->getServiceContainer();$cfg=$s->getMainConfig();if($cfg->get('DBserver')!=='127.0.0.1:3307'||$cfg->get('MeridianAutowikiRequireVerifiedRelease')||!str_contains(str_replace('\\','/',Assets::root()),'/restore-test/'))throw new RuntimeException('Disposable public-view fixture required');
  $store=new Store();$store->install();$db=$s->getConnectionProvider()->getPrimaryDatabase();$user=$s->getUserFactory()->newFromName('Moonridden');$anon=$s->getUserFactory()->newAnonymous();$nonce=bin2hex(random_bytes(8));
  // Each fixture starts independently of earlier disposable publications.
  $db->update('maw_state',['value'=>''],['name'=>['active','search']],__METHOD__);
  $png=function($red,$blue)use($nonce){$im=imagecreatetruecolor(2,2);imagefill($im,0,0,imagecolorallocate($im,$red,73,$blue));ob_start();imagepng($im);$bytes=ob_get_clean();imagedestroy($im);$hash=hash('sha256',$bytes);$file=Assets::path($hash);if(!is_dir(dirname($file)))mkdir(dirname($file),0770,true);file_put_contents($file,$bytes);return ['hash'=>$hash,'bytes'=>$bytes];};$oldImage=$png(200,0);$newImage=$png(0,200);
  $item=['kind'=>'entity','id'=>'/obj/item/public_view_'.$nonce,'fields'=>$this->fields('entity')];$item['fields']=array_replace($item['fields'],['name'=>'Preservation Tool '.$nonce,'description'=>'Public source fixture','force'=>5,'icon_file'=>'entity-'.substr($oldImage['hash'],0,32).'.png','icon_source'=>'icons/fixture.dmi','icon_state'=>'old']);$key=Package::recordKey($item);
  $vendor=['kind'=>'vending','id'=>'/obj/machinery/vending/public_view_'.$nonce,'fields'=>$this->fields('vending')];$vendor['fields']=array_replace($vendor['fields'],['name'=>'Preservation Vendor '.$nonce,'default_price'=>5,'products'=>[['key'=>$item['id'],'value'=>2]]]);$vendorKey=Package::recordKey($vendor);
  $import=function($suffix,$records,$image)use($store,$db,$nonce,$key){$build=hash('sha256',$nonce.$suffix);$store->import(['id'=>$build,'manifest'=>['source'=>['commit'=>str_repeat('a',40)],'publicationReady'=>true,'provenance'=>['dirty'=>false],'datasets'=>[['kind'=>'entity','count'=>1],['kind'=>'vending','count'=>1]]],'records'=>$records]);$db->insert('maw_asset',['build'=>$build,'record'=>$key,'hash'=>$image['hash'],'width'=>2,'height'=>2,'profile'=>'initial-south-first-frame'],__METHOD__);return $build;};
  $first=$import('first',[$key=>$item,$vendorKey=>$vendor],$oldImage);SearchIndex::prepare($store,$first);$store->activate($first,$store->active(),$user);$pub=PublicationLog::latest($first)['id'];
  $item['fields']['force']=99;$item['fields']['icon_file']='entity-'.substr($newImage['hash'],0,32).'.png';$item['fields']['icon_state']='new';$vendor['fields']['products']=[];$vendor['fields']['default_price']=9;$second=$import('second',[$key=>$item,$vendorKey=>$vendor],$newImage);$saved=[];$decisions=[];
  foreach([$key,$vendorKey] as $target){$p=Preservation::preview($store,$second,$target,$pub);$d=['version'=>1,'target'=>$target,'type'=>'preserve','value'=>json_encode(['forBuild'=>$second,'publication'=>$pub]),'reason'=>'Retain the reviewed original source','watch'=>['preservation'],'fingerprint'=>$p['fingerprint'],'state'=>'active'];$decisionKey=hash('sha256',$nonce.$target);$saved[$target]=Submission::save($store,$d,$second,$decisionKey,0,$user);$decisions[$target]=[$decisionKey,$d];}DeferredUpdates::doUpdates();
  SearchIndex::prepare($store,$second);$store->activate($second,$first,$user);$r=$store->publicRecord($second,$key);
  $this->check($r['fields']['force']===5&&$r['sourceBuild']===$first&&$store->record($second,$key)['fields']['force']===99,'Public data uses the retained source while the replacement remains immutable');
  $this->check($this->api($anon,$key)['effective']['fields']['force']===5&&$this->api($user,$key)['record']['fields']['force']===99,'Anonymous API reads agree with publication while reviewer evidence remains raw');
  $this->check($this->image($anon,$second,$key)['bytes']===$oldImage['bytes']&&$this->image($user,$second,$key)['bytes']===$oldImage['bytes'],'The public image URL serves the approved original to visitors and editors');
  $this->check($this->image($user,$second,$key,true)['bytes']===$newImage['bytes']&&$this->image($anon,$second,$key,true)['bytes']===$oldImage['bytes'],'Only authorized explicit review previews can show the replacement image');
  $this->check($this->image($anon,$first,$key)['status']===404&&$this->image($anon,$second,$key)['cache']==='private, no-store','Historical image URLs remain private and public image delivery is not cached');
  $related=$store->view($second)->related($vendorKey);$reverse=$store->view($second)->related($key);$this->check(count($related)===1&&$related[0]['record']['key']===$key&&$related[0]['quantity']===2&&$reverse[0]['record']['key']===$vendorKey,'Both relationship directions use retained fields instead of replacement edges');
  $title=MediaWiki\Title\Title::newFromText('User:Moonridden/Public View '.$nonce);$markup='{{#gamefact:'.$key.'|force}} {{#gameicon:'.$key.'}} {{#gameitem:'.$key.'}}';$render=fn()=>$s->getParserFactory()->create()->parse($markup,$title,MediaWiki\Parser\ParserOptions::newFromUser($anon))->getRawText();$html=$render();
  $this->check(str_contains($html,'Retained documentation from an earlier build')&&str_contains($html,'>5<')&&!str_contains($html,'>99<'),'Rendered guide facts and icons visibly identify older documentation');
  $reference=new Reference();$ctx=$this->context($anon);$reference->setContext($ctx);$reference->execute($key);$html=$ctx->getOutput()->getHTML();$this->check(str_contains($html,$first)&&str_contains($html,'Retained documentation'),'The full reference exposes the original source provenance');
  if(SearchIndex::enabled())$this->check(in_array('game:'.$key,array_column(SearchIndex::search($nonce,20),'id'),true),'The real semantic search collection returns the approved retained record');
  $note=['version'=>1,'target'=>$key,'type'=>'annotation','value'=>'A current human explanation','reason'=>'Additional context','watch'=>[],'fingerprint'=>str_repeat('0',64),'state'=>'active'];Submission::save($store,$note,$second,hash('sha256',$nonce.'note'),0,$user);DeferredUpdates::doUpdates();$this->check(in_array($note['value'],$store->publicRecord($second,$key)['annotations'],true),'A plain human explanation remains visible without replacing source data');
  $hide=$note;$hide['type']='visibility';$hide['value']='hidden';$hidden=Submission::save($store,$hide,$second,hash('sha256',$nonce.'hidden'),0,$user);DeferredUpdates::doUpdates();$this->check(($this->api($anon,$key)['missing']??false)&&$this->image($anon,$second,$key)['status']===404,'Current visibility restrictions block retained API data and images');
  $hide['state']='revoked';Submission::save($store,$hide,$second,hash('sha256',$nonce.'hidden'),$hidden['revision'],$user);DeferredUpdates::doUpdates();
  [$decisionKey,$d]=$decisions[$key];$d['state']='revoked';Submission::save($store,$d,$second,$decisionKey,$saved[$key]['revision'],$user);DeferredUpdates::doUpdates();$this->check($store->publicRecord($second,$key)===null&&($this->api($anon,$key)['missing']??false)&&$this->image($anon,$second,$key)['status']===404,'Revocation cannot fall back to unreviewed replacement facts or images');
  $this->check(str_contains($render(),'Reference unavailable')&&$store->view($second)->related($vendorKey)===[],'Guide rendering and related records respect the same revocation');
  if(SearchIndex::enabled())$this->check(!in_array('game:'.$key,array_column(SearchIndex::search($nonce,20),'id'),true),'Stale search documents cannot expose a revoked source');
  SearchIndex::prepare($store,$second,false);$store->refreshSearch();$this->check($store->publicRecord($second,$key)===null&&!in_array($key,array_column(iterator_to_array($store->publicRecords($second)),'key'),true),'A background refresh cannot publish an unassessed replacement');
  SearchIndex::prepare($store,$second);$store->activate($second,$second,$user);$this->check($store->publicRecord($second,$key)['fields']['force']===99,'An explicit new publication can adopt the replacement source');
  $correction=$note;$correction['type']='correction';$correction['value']='3';$correction['watch']=['force'];$correctionKey=hash('sha256',$nonce.'correction');$corrected=Submission::save($store,$correction,$second,$correctionKey,0,$user);DeferredUpdates::doUpdates();$this->check($store->publicRecord($second,$key)===null,'A factual correction waits for semantic reassessment');
  $publishedPayload=$db->selectField('maw_live_public','payload',['build'=>$second,'record'=>$key],__METHOD__);$publishedSearch=$store->state('search');
  SearchIndex::prepare($store,$second);
  $this->check($db->selectField('maw_live_public','payload',['build'=>$second,'record'=>$key],__METHOD__)===$publishedPayload,'Same-build preparation leaves the published catalogue intact');
  try{$store->refreshSearch();throw new LogicException('A refresh must not approve a new correction');}catch(RuntimeException){$this->check($store->state('search')===$publishedSearch,'Background refresh cannot select an unpublished candidate search collection');}
  $store->activate($second,$second,$user);$this->check($store->publicRecord($second,$key)['fields']['force']===3,'The published correction is part of the approved public view');
  $correction['state']='revoked';Submission::save($store,$correction,$second,$correctionKey,$corrected['revision'],$user);DeferredUpdates::doUpdates();$this->check($store->publicRecord($second,$key)===null,'Revoking a factual correction also requires reassessment before raw fallback');
  if(SearchIndex::enabled()){
   $page=$s->getWikiPageFactory()->newFromTitle($title);$up=$page->newPageUpdater($user);$up->grabParentRevision();$up->setContent(MediaWiki\Revision\SlotRecord::MAIN,MediaWiki\Content\ContentHandler::makeContent($markup,$title));$up->saveRevision(MediaWiki\CommentStore\CommentStoreComment::newUnsavedComment('Isolated delivery outage fixture.'));if(!$up->getStatus()->isOK())throw new RuntimeException('Fixture guide save failed');DeferredUpdates::doUpdates();
   $purged=0;$s->getHookContainer()->register('ArticlePurge',static function($p)use($title,&$purged){if($p->getTitle()->equals($title))$purged++;});
   // Suspend unrelated disposable queue entries while testing an actual worker failure.
   $pending=[];foreach($db->select('maw_outbox','id',['status'=>'pending'],__METHOD__) as $row)$pending[]=$row->id;
   if($pending)$db->update('maw_outbox',['status'=>'fixture-paused'],['id'=>$pending],__METHOD__);
   $originalKeyFile=$GLOBALS['wgMeridianSearchAdminKeyFile'];$searchBefore=$store->state('search');
   try{
    $GLOBALS['wgMeridianSearchAdminKeyFile']=Assets::root().'/missing-key-'.$nonce;
    if($cfg->get('MeridianSearchAdminKeyFile')!==$GLOBALS['wgMeridianSearchAdminKeyFile'])throw new RuntimeException('Fixture search outage was not applied');
    $store->enqueue('outage-a-'.$nonce,'refresh',['target'=>$key]);$store->enqueue('outage-b-'.$nonce,'refresh',['target'=>$key]);
    $result=Meridian\Autowiki\Delivery::run();
    $this->check($result['failed']===2&&$purged===2&&$store->state('search')===$searchBefore,'Both guide invalidations run even when search delivery fails; publication stays unchanged');
   }finally{$GLOBALS['wgMeridianSearchAdminKeyFile']=$originalKeyFile;if($pending)$db->update('maw_outbox',['status'=>'pending'],['id'=>$pending],__METHOD__);}
  }
  $this->output('SUCCESS '.$this->checks.' public view assertions; semantic search '.(SearchIndex::enabled()?'enabled':'disabled').".\n");
 }
}
$maintClass=AutowikiPublicViewTest::class;require RUN_MAINTENANCE_IF_MAIN;
