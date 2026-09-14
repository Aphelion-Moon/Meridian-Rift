<?php
namespace Meridian\Autowiki;

use MediaWiki\MediaWikiServices;
use RuntimeException;

/** The same evidence checks serve individual and bounded bulk submissions. */
final class Submission {
 public static function save(Store $store,array $d,string $build,string $key,int $base,$user):array {
  $result=Decisions::save(self::prepare($store,$d,$build,$base),$key,$base,$user);$store->snapshot(false);return $result;
 }
 public static function prepare(Store $store,array $d,string $build,int $base):array {
  if(!preg_match('/^[a-f0-9]{64}$/',$build))throw new RuntimeException('Select a source build');
  // Revocation needs the prior wiki revision, not a still-present source field.
  // Decisions::save retains the original evidence after locking that revision.
  if(($d['state']??'')==='revoked'&&$base>0)return $d;
  if(($d['state']??'')!=='revoked')$d['evidence']=['build'=>$build];
  if(($d['type']??'')==='relink')return Relink::prepare($store,$d,$build,$base);
  if(($d['type']??'')==='preserve')return Preservation::prepare($store,$d,$build,$base);
  if(in_array($d['type']??'', ['asset','asset-reject'],true)){ $issue=$store->getIssue($d['target']??'');if(!$issue)throw new RuntimeException('Image review issue is absent');if(($d['state']??'')!=='revoked')$d=AssetDecision::prepare($store,$d,$build,$issue);return $d;}
  $r=$store->record($build,$d['target']??'');
  $issue=in_array($d['type']??'', ['triage','assignment'],true)?$store->getIssue($d['target']??''):null;
  $revoked=($d['state']??'')==='revoked'&&$base>0;
  if(!$r&&!$issue&&!$revoked)throw new RuntimeException('Select an existing source record or issue');
  if($r)foreach($d['watch']??[] as $field)if(!array_key_exists($field,$r['fields']))throw new RuntimeException('Unknown watched source field');
  if(!$revoked&&in_array($d['type']??'', ['match','reject','family'],true)&&!$store->record($build,$d['value']??''))throw new RuntimeException('Candidate identity is absent from this build');
  if(!$revoked&&in_array($d['type']??'', ['match','family'],true)){
   $candidate=$store->record($build,$d['value']);
   if(!$r||$candidate['kind']!==$r['kind']||$candidate['key']===$r['key'])throw new RuntimeException('Choose a different record of the same kind');
  }
  if($issue&&!$revoked){
   if($d['type']==='triage'){
    $expected=Package::fingerprint(['observation'=>$issue['observation']],['observation']);
    if(!hash_equals($expected,$d['fingerprint']??''))throw new RuntimeException('Issue evidence changed since preview; reload before deciding');
    $d['watch']=['observation'];
   }else{
    $assignee=MediaWikiServices::getInstance()->getUserFactory()->newFromName($d['value']);
    if(!$assignee||!$assignee->getId())throw new RuntimeException('Select an existing wiki editor');
    $d['watch']=[];$d['fingerprint']=Package::fingerprint([],[]);
   }
  }elseif(!$revoked)$d['fingerprint']=Package::fingerprint($r['fields']??[],$d['watch']??[]);
  if(($d['type']??'')==='correction'&&!$revoked){
   $fields=$r['fields'];$field=$d['watch'][0]??'';
   if(!array_key_exists($field,$fields))throw new RuntimeException('Select the corrected field');
   $fields[$field]=json_decode($d['value'],true,32,JSON_THROW_ON_ERROR);Package::validateFields($r['kind'],$fields);
  }
  return $d;
 }
}
