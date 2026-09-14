<?php
namespace Meridian\Autowiki;
use MediaWiki\Content\JsonContent;
final class DecisionContent extends JsonContent {
 public function __construct($text,$modelId='meridian-decision'){parent::__construct($text,$modelId);}
 public function isValid(){if(!parent::isValid())return false;try{Decisions::validate(json_decode($this->getText(),true,64,JSON_THROW_ON_ERROR));return true;}catch(\Throwable){return false;}}
}
