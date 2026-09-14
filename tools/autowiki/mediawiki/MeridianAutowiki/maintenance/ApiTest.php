<?php
use MediaWiki\Maintenance\Maintenance;
use MediaWiki\Context\{RequestContext,DerivativeContext};
use MediaWiki\Request\FauxRequest;
use MediaWiki\Api\{ApiMain,ApiQueryTokens};
use Meridian\Autowiki\{Store,Package};
class AutowikiApiTest extends Maintenance {
 private function call(array $params,$user):array{
  $request=new FauxRequest($params+['format'=>'json','formatversion'=>2],true);$context=new DerivativeContext(RequestContext::getMain());$context->setUser($user);$context->setRequest($request);$request->setVal('token',ApiQueryTokens::getToken($user,$request->getSession(),'')->toString());
  $api=new ApiMain($context,true);$api->execute();return $api->getResult()->getResultData(null,['Strip'=>'all']);
 }
 public function execute(){
  $s=$this->getServiceContainer();if($s->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated API tests required');$user=$s->getUserFactory()->newFromName('Moonridden');$store=new Store();$status=$this->call(['action'=>'autowikidata','view'=>'status'],$user);if(!isset($status['autowikidata']['builds']))throw new RuntimeException('Reviewer API status unavailable');
  foreach(['status','publication','preservation','issues'] as $view){$denied=false;try{$this->call(['action'=>'autowikidata','view'=>$view],$s->getUserFactory()->newAnonymous());}catch(Throwable $e){$denied=str_contains($e->getMessage(),'Review access');}if(!$denied)throw new RuntimeException('Anonymous review data was not refused');}
  $db=$s->getConnectionProvider()->getPrimaryDatabase();$eventIssue=$db->selectField('maw_issue_event','issue',[],__METHOD__,['ORDER BY'=>'sequence DESC','LIMIT'=>1]);if($eventIssue){$history=$this->call(['action'=>'autowikidata','view'=>'issues','key'=>$eventIssue,'offset'=>20],$user);if(!isset($history['autowikidata']['issue']['detection']['history'],$history['autowikidata']['issue']['detection']['moreHistory']))throw new RuntimeException('Reviewer detector history API unavailable');}
  $findings=$this->call(['action'=>'autowikidata','view'=>'publication','build'=>$status['autowikidata']['builds'][0]['id']],$user);if(!isset($findings['autowikidata']['rows']))throw new RuntimeException('Reviewer findings API unavailable');
  $build='1e173d1211988c445b6c8c1ba437f6c8d87027c80197dabc773acc53b5b63a18';$target=Package::key('entity','/obj/item/wrench');$key=hash('sha256',bin2hex(random_bytes(8)));$before=count($store->decisions($target));$d=['version'=>1,'target'=>$target,'type'=>'annotation','value'=>'API fixture','reason'=>'Malformed bulk must not save its first row','watch'=>[],'fingerprint'=>str_repeat('0',64),'state'=>'active'];
  $choices=$this->call(['action'=>'autowikidata','view'=>'preservation','build'=>$build,'key'=>$target],$user);if(!isset($choices['autowikidata']['rows'],$choices['autowikidata']['more']))throw new RuntimeException('Reviewer publication history is unavailable');
  $preview=$this->call(['action'=>'autowikidata','view'=>'preservation','build'=>$build,'key'=>$target,'publication'=>str_repeat('0',64)],$user);if(($preview['autowikidata']['eligible']??true)!==false)throw new RuntimeException('Invented publication was eligible for preservation');
  $denied=false;try{$this->call(['action'=>'autowikidecision','operation'=>'bulk','build'=>$build,'payload'=>json_encode([['key'=>$key,'base'=>0,'decision'=>$d],['decision'=>$d]])],$user);}catch(Throwable $e){$denied=str_contains($e->getMessage(),'Malformed bulk entry');}if(!$denied||count($store->decisions($target))!==$before)throw new RuntimeException('Malformed bulk was not rejected before all writes');
  $this->output("PASS reviewer API access, anonymous denial and malformed-bulk atomic prevalidation through ApiMain.\n");
 }
}
$maintClass=AutowikiApiTest::class;require RUN_MAINTENANCE_IF_MAIN;
