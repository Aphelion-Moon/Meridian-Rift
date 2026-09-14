<?php
namespace Meridian\Autowiki;
/** Durable transition notices through the existing private Discord outbox. */
final class OperationsNotifier {
 private const MESSAGES=[
  'delivery-failed'=>'Background delivery failed; inspect Publications and retry after correcting the cause.',
  'delivery-stalled'=>'Background work has waited at least 15 minutes; check the wiki job runner.',
  'deployment-failed'=>'The running-build check failed; inspect the protected receiver diagnostics.',
  'deployment-stale'=>'The running-build check has stopped reporting; check the wiki job runner.',
  'deployment-awaiting-package'=>'Package generation or retrieval needs attention; inspect Publications for the next action.'
 ];
 public static function configured(array $health):array {
  global $wgMeridianAutowikiOperationsNotifications,$wgDiscordQueueDirectory,$wgDiscordWebhookURL;
  $options=$wgMeridianAutowikiOperationsNotifications??[];
  if(!is_array($options)||($options['enabled']??false)!==true)return ['state'=>'disabled'];
  return self::observe($health,['directory'=>$options['directory']??'','queue'=>$wgDiscordQueueDirectory??'','urls'=>$wgDiscordWebhookURL??[]]);
 }
 public static function observe(array $health,array $options):array {
  if(!in_array($health['state']??null,['healthy','waiting','error'],true)||!is_array($health['findings']??null))throw new \RuntimeException('Invalid operations observation');
  foreach($health['findings'] as $finding)if(($finding['severity']??null)==='error'&&!isset(self::MESSAGES[$finding['code']??'']))throw new \RuntimeException('Unknown operations failure');
  $root=$options['directory'];$queue=$options['queue'];
  foreach([$root,$queue] as $path)if(!is_string($path)||!preg_match('~^(?:[A-Za-z]:[/\\\\]|/)~',$path))throw new \RuntimeException('Notification storage must be absolute');
  if(!is_dir($root)&&!mkdir($root,0700,true)&&!is_dir($root))throw new \RuntimeException('Notification state is unavailable');
  if(!is_dir($queue))throw new \RuntimeException('Discord outbox is unavailable');
  $urls=is_string($options['urls'])?[$options['urls']]:$options['urls'];
  if(!is_array($urls)||!$urls||count($urls)>16)throw new \RuntimeException('Discord notification destination is unavailable');
  foreach($urls as $url)if(!is_string($url)||strlen($url)>2048||!preg_match('~^https://(?:canary\.|ptb\.)?discord\.com/api(?:/v[0-9]+)?/webhooks/[0-9]+/[A-Za-z0-9._-]+$~D',$url))throw new \RuntimeException('Invalid Discord destination');
  $urls=array_values(array_unique($urls));sort($urls,SORT_STRING);
  $lock=fopen($root.'/state.lock','c');if(!$lock)throw new \RuntimeException('Notification lock unavailable');
  try {
   if(!flock($lock,LOCK_EX|LOCK_NB))return ['state'=>'busy'];
   $path=$root.'/state.json';$state=['version'=>1,'sequence'=>0,'active'=>[],'pending'=>null];
   if(is_file($path)){
    if(filesize($path)>65536)throw new \RuntimeException('Notification state is oversized');
    $state=json_decode(file_get_contents($path),true,32,JSON_THROW_ON_ERROR);
    if(!is_array($state)||($state['version']??null)!==1||!is_int($state['sequence']??null)||$state['sequence']<0||!is_array($state['active']??null)||!array_key_exists('pending',$state))throw new \RuntimeException('Invalid notification state');
   }
   // Finish the already-recorded transition before considering newer observations.
   $resumed=$state['pending']!==null;if($resumed)self::deliver($state,$path,$queue);
   $codes=[];
   foreach($health['findings']??[] as $finding)if(($finding['severity']??'')==='error'&&isset(self::MESSAGES[$finding['code']??'']))$codes[]=$finding['code'];
   $codes=array_values(array_unique($codes));sort($codes,SORT_STRING);
   if($codes===$state['active'])return ['state'=>$resumed?'queued':'unchanged'];
   $message=$codes?'Autowiki needs attention. '.implode(' ',array_map(static fn($code)=>self::MESSAGES[$code],$codes)):'Autowiki background checks have recovered. Publication may still be waiting for a trusted game package; see Publications for current status.';
   $message.=' https://meridian-wiki.a13.info/wiki/Special:Autowiki?awview=publications';
   $state['sequence']++;$state['pending']=['sequence'=>$state['sequence'],'codes'=>$codes,'message'=>$message,'urls'=>$urls];
   self::save($path,$state);self::deliver($state,$path,$queue);
   return ['state'=>'queued'];
  } finally {flock($lock,LOCK_UN);fclose($lock);}
 }
 private static function save(string $path,array $state):void {
  $tmp=$path.'.'.bin2hex(random_bytes(8)).'.pending';
  try {if(file_put_contents($tmp,json_encode($state,JSON_THROW_ON_ERROR),LOCK_EX)===false||!rename($tmp,$path))throw new \RuntimeException('Notification state write failed');}
  finally {if(is_file($tmp))unlink($tmp);}
 }
 private static function deliver(array &$state,string $statePath,string $queue):void {
  $event=$state['pending'];
  if(!is_array($event)||!is_int($event['sequence']??null)||!is_array($event['codes']??null)||!is_array($event['urls']??null)||!is_string($event['message']??null))throw new \RuntimeException('Invalid pending notification');
  foreach($event['urls'] as $url){
   $id=hash('sha256','autowiki-operations:'.$event['sequence'].':'.$url);$path=$queue.'/'.$id.'.json';
   // Failed requests remain for the established worker's operator recovery.
   if(is_file($path)||is_file($queue.'/'.$id.'.failed'))continue;
   $request=['method'=>'POST','url'=>$url,'headers'=>['Content-Type'=>'application/json','User-Agent'=>'MeridianAutowiki/0.2'],'body'=>json_encode(['content'=>$event['message'],'allowed_mentions'=>['parse'=>[]]],JSON_THROW_ON_ERROR)];
   self::save($path,['id'=>$id,'created'=>time(),'attempts'=>0,'next_attempt'=>time(),'request'=>$request]);
  }
  $state['active']=$event['codes'];$state['pending']=null;self::save($statePath,$state);
 }
}
