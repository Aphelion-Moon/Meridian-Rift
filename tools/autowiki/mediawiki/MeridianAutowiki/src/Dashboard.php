<?php
namespace Meridian\Autowiki;
use MediaWiki\SpecialPage\SpecialPage;
use MediaWiki\Html\Html;
final class Dashboard extends SpecialPage {
 public function __construct(){parent::__construct('Autowiki');}
 public function execute($subpage){$this->setHeaders();$out=$this->getOutput();if(!Decisions::canReview($this->getUser())){$out->addHTML(Html::element('p',[],'Sign in with an editor account to use the Autowiki Workshop.'));return;}$out->addHTML(Html::element('a',['href'=>\MediaWiki\Title\Title::newFromText('Help:Autowiki')->getLocalURL()],'Workshop Help and Editing Guide'));$out->addModules('ext.meridianAutowiki');$out->addHTML(Html::rawElement('div',['id'=>'maw-dashboard'],Html::element('p',[],'Loading the workshop…')));}
}
