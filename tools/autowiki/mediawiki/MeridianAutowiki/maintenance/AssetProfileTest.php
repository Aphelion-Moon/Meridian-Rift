<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{AssetDecision,Decisions,Package};
class AutowikiAssetProfileTest extends Maintenance {
 public function execute(){
  $profile=array_values(array_filter(array_keys(Package::contract()['renderProfiles']),static fn($p)=>$p!=='initial-south-first-frame'))[0];
  $fields=['render_profiles'=>[['key'=>$profile,'value'=>[['key'=>'source','value'=>'icons/item.dmi'],['key'=>'state','value'=>'held'],['key'=>'scope','value'=>'Left hand layer'],['key'=>'file','value'=>'appearance-'.str_repeat('a',32).'.png']]],['key'=>'other','value'=>[['key'=>'state','value'=>'unrelated']]]]];
  $d=['version'=>1,'target'=>str_repeat('b',64),'type'=>'asset-reject','value'=>json_encode(['entity'=>str_repeat('c',64),'filename'=>'Fixture.png','expectedImageHash'=>'abc123','profile'=>$profile]),'reason'=>'Profile fixture','watch'=>['selected_profile'],'fingerprint'=>Package::fingerprint(['selected_profile'=>AssetDecision::profileEvidence($fields,$profile)],['selected_profile']),'state'=>'active'];
  if(!Decisions::applicable($d,['fields'=>$fields]))throw new RuntimeException('Current selected profile was rejected');
  $other=$fields;$other['render_profiles'][1]['value'][0]['value']='changed';if(!Decisions::applicable($d,['fields'=>$other]))throw new RuntimeException('Unrelated profile invalidated human evidence');
  $selected=$fields;$selected['render_profiles'][0]['value'][1]['value']='changed';if(Decisions::applicable($d,['fields'=>$selected]))throw new RuntimeException('Changed selected profile retained approval');
  $reordered=$fields;$reordered['render_profiles'][0]['value']=array_reverse($reordered['render_profiles'][0]['value']);if(!Decisions::applicable($d,['fields'=>$reordered]))throw new RuntimeException('Metadata ordering invalidated evidence');
  if(Decisions::applicable($d,['fields'=>['render_profiles'=>[]]]))throw new RuntimeException('Absent profile retained approval');
  $legacy=$d;$legacy['watch']=['render_profiles'];$legacy['fingerprint']=Package::fingerprint($fields,$legacy['watch']);if(!Decisions::applicable($legacy,['fields'=>$fields])||Decisions::applicable($legacy,['fields'=>$other]))throw new RuntimeException('Existing human revisions changed meaning');
  $this->output("PASS 6 profile evidence checks, including unrelated changes, missing profiles and legacy human revisions.\n");
 }
}
$maintClass=AutowikiAssetProfileTest::class;require RUN_MAINTENANCE_IF_MAIN;
