<?php
namespace Meridian\Autowiki;

/** Additive, repeatable schema installation for maintenance and deployment. */
final class Schema {
 public static function install($db):void {
  $db->sourceFile(__DIR__.'/../sql/tables.sql');
  if(!$db->fieldExists('maw_prepared_evidence','selection_digest',__METHOD__))$db->query('ALTER TABLE '.$db->tableName('maw_prepared_evidence')." ADD selection_digest VARBINARY(64) NOT NULL DEFAULT ''",__METHOD__);
 }
}
