<?php
namespace Meridian\Autowiki;

use MediaWiki\MediaWikiServices;
use RuntimeException;

/** Content-addressed PNGs live outside the web root. Visibility is checked at delivery. */
final class Assets {
 public static function root(): string {
  $root = MediaWikiServices::getInstance()->getMainConfig()->get('MeridianAutowikiPackageRoot');
  if (!$root || !is_dir($root)) throw new RuntimeException('The managed asset directory is not configured');
  return rtrim($root, '/\\');
 }
 public static function path(string $hash): string {
  if (!preg_match('/^[a-f0-9]{64}$/', $hash)) throw new RuntimeException('Invalid image identity');
  return self::root().'/images/'.substr($hash, 0, 2).'/'.$hash.'.png';
 }
 public static function stage(array $package): int {
  $db = MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();
  $count = 0;
  foreach ($package['manifest']['icons'] ?? [] as $icon) {
   $path = self::path($icon['sha256']);
   if (!is_file($path)) {
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0750, true) && !is_dir($directory)) throw new RuntimeException('Cannot create asset directory');
    $temporary = $path.'.'.bin2hex(random_bytes(6)).'.tmp';
    if (!copy($package['root'].'/icons/'.$icon['filename'], $temporary)) throw new RuntimeException('Cannot stage image');
    if (hash_file('sha256', $temporary) !== $icon['sha256']) { unlink($temporary); throw new RuntimeException('Staged image failed integrity check'); }
    if (!rename($temporary, $path)) { unlink($temporary); throw new RuntimeException('Cannot promote image'); }
    $count++;
   } elseif (hash_file('sha256', $path) !== $icon['sha256']) {
    throw new RuntimeException('Existing managed image failed integrity check');
   }
   $db->insert($icon['appearanceProfile']==='initial-south-first-frame'?'maw_asset':'maw_render', ['build'=>$package['id'], 'record'=>(new Store())->canonicalKey($package['id'],Package::key('entity', $icon['entity'])), 'hash'=>$icon['sha256'], 'width'=>$icon['width'], 'height'=>$icon['height'], 'profile'=>$icon['appearanceProfile']], __METHOD__, ['IGNORE']);
  }
  return $count;
 }
 public static function get(string $build, string $record,string $profile='initial-south-first-frame'): ?array {
  $db = MediaWikiServices::getInstance()->getConnectionProvider()->getPrimaryDatabase();
  $row = $db->selectRow($profile==='initial-south-first-frame'?'maw_asset':'maw_render', '*', ['build'=>$build, 'record'=>$record,'profile'=>$profile], __METHOD__);
  return $row ? (array)$row : null;
 }
}
