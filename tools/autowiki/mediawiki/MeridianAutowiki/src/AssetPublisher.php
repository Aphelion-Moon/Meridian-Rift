<?php
namespace Meridian\Autowiki;

use MediaWiki\MediaWikiServices;
use MediaWiki\Revision\SlotRecord;
use MediaWiki\Content\ContentHandler;
use MediaWiki\CommentStore\CommentStoreComment;
use MediaWiki\Deferred\DeferredUpdates;
use RuntimeException;

/** Applies only durable reviewed filename mappings to the active validated build. */
final class AssetPublisher {
 public static function publish(Store $store):array {
  $build=$store->active();if(!$build)return ['changed'=>0,'conflicts'=>0];
  $s=MediaWikiServices::getInstance();$db=$s->getConnectionProvider()->getPrimaryDatabase();$repo=$s->getRepoGroup()->getLocalRepo();
  $user=$s->getUserFactory()->newFromName('Moonridden');if(!$user?->getId())throw new RuntimeException('Publication attribution account is missing');
  $changed=0;$conflicts=0;
  foreach($db->select(['maw_decision','page','revision'],'maw_decision.*',['type'=>'asset','maw_decision.revision = page_latest','(rev_deleted & 1) = 0'],__METHOD__,[],['page'=>['JOIN','page_id = maw_decision.page'],'revision'=>['JOIN','rev_id = page_latest']]) as $row){
   $d=json_decode($row->payload,true);if($d['state']!=='active')continue;$v=AssetDecision::value($d['value']);$r=$store->view($build)->mappingRecord($v['entity']);$asset=$r?Assets::get($r['sourceBuild']??$build,$r['sourceKey']??$r['key'],$v['profile']??'initial-south-first-frame'):null;
   if(!$r||!$asset||!Decisions::applicable($d,$r))continue;
   if($asset['profile']!=='initial-south-first-frame'){$profile=Package::profiles($r)[$asset['profile']];$r['fields']['icon_source']=$profile['source'];$r['fields']['icon_state']=$profile['state'];}
   $source=Assets::path($asset['hash']);if(!is_file($source)||hash_file('sha256',$source)!==$asset['hash'])throw new RuntimeException('Managed source image failed validation');
   $file=$repo->newFile($v['filename']);$file->load(\Wikimedia\Rdbms\IDBAccessObject::READ_LATEST);$currentHash=$file->getSha1();
   $previous=$db->selectRow('maw_asset_delivery','*',['page'=>$row->page],__METHOD__);
   $same=$file->exists()&&is_file($file->getLocalRefPath())&&hash_file('sha256',$file->getLocalRefPath())===$asset['hash'];
   $signature=hash('sha256',json_encode([$asset['hash'],$r['id'],$r['fields']['icon_source'],$r['fields']['icon_state'],$asset['profile']],JSON_THROW_ON_ERROR));
   if(!$same&&$currentHash!==$v['expectedImageHash']&&$currentHash!==($previous->image_hash??null)){
    $store->issue($d['target'],'image-edit-conflict',$build,['filename'=>$v['filename'],'reason'=>'The wiki image changed outside the reviewed publication. Compare it before accepting a replacement.']);$conflicts++;continue;
   }
   if(!$same||!$previous||$previous->signature!==$signature){
    $page=$s->getWikiPageFactory()->newFromTitle($file->getTitle());$oldText=$page->getRevisionRecord()?->getContent(SlotRecord::MAIN)?->serialize()??'';
    $commit=$db->selectField('maw_build','source',['id'=>$r['sourceBuild']??$build],__METHOD__);
    $url='https://github.com/Aphelion-Moon/Meridian-Rift/blob/'.$commit.'/'.implode('/',array_map('rawurlencode',explode('/',$r['fields']['icon_source'])));
    if(str_starts_with($r['fields']['icon_source'],'greyscale:'))$url='https://github.com/Aphelion-Moon/Meridian-Rift/tree/'.$commit;
    $escape=static fn($text)=>strtr(htmlspecialchars($text,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8'),['{'=>'&#123;','}'=>'&#125;','['=>'&#91;',']'=>'&#93;','|'=>'&#124;']);
    $managed="<!-- Autowiki reviewed appearance -->\n== Current Source Artwork ==\nSource: [".$url.' '.$escape($r['fields']['icon_source'])."], state <code>".$escape($r['fields']['icon_state']??'')."</code>. Appearance: ".$escape($asset['profile']).". Source identity: <code>".$escape($r['id'])."</code>. Original attribution and image licensing are retained below; the wiki text license does not replace an image license.\n<!-- End Autowiki reviewed appearance -->\n";
    $pattern='/<!-- Autowiki reviewed appearance -->[\s\S]*?<!-- End Autowiki reviewed appearance -->\n?/';
    $text=str_contains($oldText,'<!-- Autowiki reviewed appearance -->')?preg_replace_callback($pattern,static fn()=>$managed,$oldText):$managed."\n".$oldText;
    if(!$same){
     $latestFile=$repo->newFile($v['filename']);$latestFile->load(\Wikimedia\Rdbms\IDBAccessObject::READ_LATEST);if($latestFile->getSha1()!==$currentHash)throw new RuntimeException('Image changed during publication');
     $status=$file->upload($source,'Update reviewed game appearance.',$text,0,false,false,$user);if(!$status->isOK())throw new RuntimeException('Reviewed image upload failed');
    }
    DeferredUpdates::doUpdates();$page=$s->getWikiPageFactory()->newFromTitle($file->getTitle());$updater=$page->newPageUpdater($user);$parent=$updater->grabParentRevision();$latest=$parent?->getContent(SlotRecord::MAIN)?->serialize()??'';
    if($latest!==$oldText&&$latest!==$text)throw new RuntimeException('Image description changed during publication');
    if($latest!==$text){$updater->setContent(SlotRecord::MAIN,ContentHandler::makeContent($text,$page->getTitle()));$updater->saveRevision(CommentStoreComment::newUnsavedComment('Record reviewed appearance and preserve source attribution.'));if(!$updater->getStatus()->isOK())throw new RuntimeException('Image description save failed');}
    DeferredUpdates::doUpdates();$file=$repo->newFile($v['filename']);if(hash_file('sha256',$file->getLocalRefPath())!==$asset['hash'])throw new RuntimeException('Uploaded image verification failed');$changed++;
   }
   $delivery=['page'=>$row->page,'revision'=>$row->revision,'filename'=>$v['filename'],'image_hash'=>$file->getSha1(),'signature'=>$signature,'build'=>$build,'validated'=>gmdate('YmdHis')];$db->upsert('maw_asset_delivery',$delivery,['page'],$delivery,__METHOD__);
  }
  return ['changed'=>$changed,'conflicts'=>$conflicts];
 }
}
