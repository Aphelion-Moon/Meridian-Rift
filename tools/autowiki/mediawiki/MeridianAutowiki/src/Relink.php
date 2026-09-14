<?php
namespace Meridian\Autowiki;
use RuntimeException;
/** A human-confirmed address change; original records and decisions are never rewritten. */
final class Relink {
 public const WATCH=['name','display_name','title','description','parent','documentation_id'];
 public static function value(string $value):array {
  $v=json_decode($value,true,16,JSON_THROW_ON_ERROR);
  if(!is_array($v)||count($v)!==2||array_diff(array_keys($v),['candidate','previousBuild']))throw new RuntimeException('An identity link needs a candidate and a historical build');
  foreach($v as $key)if(!is_string($key)||!preg_match('/^[a-f0-9]{64}$/',$key))throw new RuntimeException('Invalid identity link evidence');return $v;
 }
 public static function prepare(Store $store,array $d,string $build,int $base):array {
  $v=self::value($d['value']);if(($d['state']??'')==='revoked'&&$base>0)return $d;
  $old=$store->declaredRecord($v['previousBuild'],$d['target']);$candidate=$store->declaredRecord($build,$v['candidate']);
  if(!$old||!$candidate||$old['kind']!==$candidate['kind'])throw new RuntimeException('Select historical and current records of the same kind');
  if($store->declaredRecord($build,$d['target']))throw new RuntimeException('This source identity still exists; use ordinary record review');
  if($old['key']===$candidate['key'])throw new RuntimeException('Select a different current identity');
  $d['watch']=self::WATCH;$d['fingerprint']=Package::fingerprint($candidate['fields'],$d['watch']);return $d;
 }
}
