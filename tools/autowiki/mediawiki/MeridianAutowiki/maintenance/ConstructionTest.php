<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Package,Reference};
class AutowikiConstructionTest extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('package','Validated construction package',true,true);}
 public function execute(){
  if($this->getServiceContainer()->getMainConfig()->get('DBserver')!=='127.0.0.1:3307')throw new RuntimeException('Isolated database required');
  $package=Package::load($this->getOption('package'));$store=new Store();$store->install();$before=$store->active();$store->import($package);
  $key=Package::key('entity','/obj/item/circuitboard/machine/bsa/back');$board=$store->record($package['id'],$key);
  if(!$board||!isset(Package::profiles($board)['initialized-machine-board-south']))throw new RuntimeException('Board data or image profile missing after PHP import');
  $edges=$store->related($package['id'],$key);$matched=false;
  foreach($edges as $edge)if($edge['field']==='construction_components'&&($edge['record']['id']??'')==='/obj/item/stock_parts/capacitor/quadratic'&&$edge['quantity']===5)$matched=true;
  if(!$matched)throw new RuntimeException('Tier-four capacitor relationship or quantity lost');
  $facts=Reference::facts($board,['construction_components','construction_scope','construction_needs_anchored']);
  if(!str_contains($facts,'× 5')||!str_contains($facts,'Initialized machine-board defaults.'))throw new RuntimeException('Construction facts or scope lost in rendering');
  $part=$store->record($package['id'],Package::key('entity','/obj/item/stock_parts/capacitor/quadratic'));
  if(($part['fields']['stock_part_tier']??null)!==4)throw new RuntimeException('Stock-part tier lost');
  if($store->active()!==$before)throw new RuntimeException('Review import changed active publication');
  $this->output("PASS actual package validation, isolated import, initialized board profile, linked tier-four requirement × 5, rendered scope, stock tier and unchanged active publication.\n");
 }
}
$maintClass=AutowikiConstructionTest::class;require RUN_MAINTENANCE_IF_MAIN;
