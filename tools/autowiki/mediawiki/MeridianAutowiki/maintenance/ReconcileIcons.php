<?php
use MediaWiki\Maintenance\Maintenance;
use Meridian\Autowiki\{Store,Package};
class AutowikiReconcileIcons extends Maintenance {
 public function __construct(){parent::__construct();$this->addOption('build','Staged source build',true,true);$this->addOption('candidates','Reviewed-format crosswalk JSON',true,true);}
 public function execute(){
  $file=$this->getOption('candidates');if(!is_file($file)||filesize($file)>32*1024*1024)throw new RuntimeException('Invalid candidate file');
  $rows=json_decode(file_get_contents($file),true,64,JSON_THROW_ON_ERROR);$store=new Store();$build=$this->getOption('build');$repo=$this->getServiceContainer()->getRepoGroup()->getLocalRepo();$count=0;
  foreach($rows as $row){
   $title=\MediaWiki\Title\Title::makeTitleSafe(NS_FILE,$row['filename']);if(!$title)throw new RuntimeException('Invalid file title');
   $file=$repo->newFile($title);if(!$file->exists())continue;
   $candidates=[];foreach(array_slice($row['candidates'],0,40) as $c){$r=$store->record($build,Package::key('entity',$c['entity']));if($r)$candidates[]=['key'=>$r['key'],'name'=>$r['name'],'source'=>$c['source'],'state'=>$c['state'],'samePixels'=>(bool)$c['samePixels']&&$row['previousSha1']===$file->getSha1()];}
   $target=hash('sha256','wiki-file:'.$title->getDBkey());
   $store->issue($target,'legacy-image',$build,['filename'=>$title->getDBkey(),'name'=>$title->getText(),'image_hash'=>$file->getSha1(),'image_url'=>$file->getFullUrl().'?mrrev='.$file->getSha1(),'uses'=>(int)$row['uses'],'candidates'=>$candidates,'reason'=>'Review the source identity and appearance before mapping this wiki image.']);$count++;
  }
  $this->output(json_encode(['issues'=>$count,'build'=>$build])."\n");
 }
}
$maintClass=AutowikiReconcileIcons::class;require RUN_MAINTENANCE_IF_MAIN;
