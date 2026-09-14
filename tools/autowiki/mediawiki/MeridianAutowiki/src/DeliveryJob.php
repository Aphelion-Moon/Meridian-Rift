<?php
namespace Meridian\Autowiki;
use MediaWiki\JobQueue\Job;
use MediaWiki\MediaWikiServices;
use MediaWiki\Title\Title;
/** Reuses the wiki's existing background runner; no additional service identity is needed. */
final class DeliveryJob extends Job {
 public function __construct($title,$params=[]){parent::__construct('meridianAutowikiDelivery',$title,$params);$this->removeDuplicates=true;}
 public static function queue():void {MediaWikiServices::getInstance()->getJobQueueGroup()->lazyPush(new self(Title::newMainPage()));}
 public function run():bool {
  try{$result=Delivery::run();if($result['busy']??false){$this->setLastError('Another Autowiki delivery is running.');return false;}if((new Store())->pending())self::queue();return true;}
  catch(\Throwable $e){wfDebugLog('MeridianAutowiki',get_class($e).': '.$e->getMessage());$this->setLastError('Autowiki delivery failed; inspect publication status.');return false;}
 }
}
