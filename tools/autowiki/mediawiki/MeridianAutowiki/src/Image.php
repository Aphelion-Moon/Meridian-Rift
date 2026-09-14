<?php
namespace Meridian\Autowiki;

use MediaWiki\SpecialPage\SpecialPage;

final class Image extends SpecialPage {
 public function __construct() { parent::__construct('AutowikiImage'); }
 public function isListed() { return false; }
 public function execute($subpage) {
  $parts = explode('/', (string)$subpage);
  $store = new Store();
  $valid = in_array(count($parts),[2,3],true) && isset(Package::contract()['renderProfiles'][$parts[2]??'initial-south-first-frame']) && preg_match('/^[a-f0-9]{64}$/', $parts[0]) && preg_match('/^[a-f0-9]{64}$/', $parts[1]);
  $asset=null;
  if($valid){$profile=$parts[2]??'initial-south-first-frame';$preview=Decisions::canReview($this->getUser())&&($parts[0]!==$store->active()||$this->getRequest()->getBool('review'));
   if($preview){$record=$store->record($parts[0],$parts[1]);$asset=$record?Assets::get($parts[0],$record['key'],$profile):null;}
   elseif($parts[0]===$store->active())$asset=$store->view($parts[0])->asset($parts[1],$profile);
  }
  $out = $this->getOutput();
  $out->disable();
  $response = $this->getRequest()->response();
  $response->header('Cache-Control: private, no-store');
  $response->header('X-Content-Type-Options: nosniff');
  $response->header('Content-Security-Policy: default-src \'none\'');
  if (!$asset || !is_file(Assets::path($asset['hash']))) { $response->statusHeader(404); return; }
  $path = Assets::path($asset['hash']);
  $response->header('Content-Type: image/png');
  $response->header('Content-Length: '.filesize($path));
  readfile($path);
 }
}
