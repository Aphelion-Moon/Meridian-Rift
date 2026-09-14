CREATE TABLE IF NOT EXISTS /*_*/maw_build (
 id BINARY(64) NOT NULL PRIMARY KEY, source BINARY(40) NOT NULL, created BINARY(14) NOT NULL,
 status VARBINARY(20) NOT NULL, manifest MEDIUMBLOB NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_record (
 build BINARY(64) NOT NULL, id BINARY(64) NOT NULL, kind VARBINARY(32) NOT NULL,
 identity VARBINARY(1024) NOT NULL, name VARBINARY(512) NOT NULL, fields MEDIUMBLOB NOT NULL,
 PRIMARY KEY(build,id), KEY kind_name(build,kind,name(100))
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_edge (
 build BINARY(64) NOT NULL, src BINARY(64) NOT NULL, dst BINARY(64) NOT NULL,
 field VARBINARY(64) NOT NULL, quantity BLOB NOT NULL,
 PRIMARY KEY(build,src,dst,field), KEY reverse_edge(build,dst)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_state (name VARBINARY(64) NOT NULL PRIMARY KEY, value BLOB NOT NULL) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_issue (
 id BINARY(64) NOT NULL PRIMARY KEY, target BINARY(64) NOT NULL, rule VARBINARY(64) NOT NULL,
 first_seen BINARY(14) NOT NULL, last_seen BINARY(14) NOT NULL, build BINARY(64) NOT NULL,
 observation BLOB NOT NULL, KEY target_rule(target,rule)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_issue_detection (
 id BINARY(64) NOT NULL PRIMARY KEY, detector VARBINARY(32) NOT NULL,
 build BINARY(64) NOT NULL, state VARBINARY(16) NOT NULL, checked BINARY(14) NOT NULL,
 fingerprint BINARY(64) NOT NULL, KEY detector_state(detector,state)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_issue_event (
 sequence BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, issue BINARY(64) NOT NULL,
 detector VARBINARY(32) NOT NULL, build BINARY(64) NOT NULL, state VARBINARY(16) NOT NULL,
 observed BINARY(14) NOT NULL, fingerprint BINARY(64) NOT NULL, observation BLOB NOT NULL,
 KEY issue_sequence(issue,sequence)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_decision (
 page INT UNSIGNED NOT NULL PRIMARY KEY, revision BIGINT UNSIGNED NOT NULL, target BINARY(64) NOT NULL,
 type VARBINARY(32) NOT NULL, payload MEDIUMBLOB NOT NULL, KEY target_type(target,type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_dependency (
 page INT UNSIGNED NOT NULL, target BINARY(64) NOT NULL, field VARBINARY(64) NOT NULL,
 PRIMARY KEY(page,target,field), KEY target(target)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_outbox (
 id BINARY(64) NOT NULL PRIMARY KEY, type VARBINARY(32) NOT NULL, payload MEDIUMBLOB NOT NULL,
 status VARBINARY(16) NOT NULL, attempts INT UNSIGNED NOT NULL DEFAULT 0, error VARBINARY(255) NOT NULL DEFAULT '',
 created BINARY(14) NOT NULL, KEY pending(status,created)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_asset (
 build BINARY(64) NOT NULL, record BINARY(64) NOT NULL, hash BINARY(64) NOT NULL,
 width INT UNSIGNED NOT NULL, height INT UNSIGNED NOT NULL, profile VARBINARY(64) NOT NULL,
 PRIMARY KEY(build,record), KEY content_hash(hash)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_public (
 build BINARY(64) NOT NULL, record BINARY(64) NOT NULL, name VARBINARY(512) NOT NULL,
 kind VARBINARY(32) NOT NULL, family BINARY(64) NOT NULL, payload MEDIUMBLOB NOT NULL,
 PRIMARY KEY(build,record), KEY public_name(build,name(100)), KEY family(build,family)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_release (
 build BINARY(64) NOT NULL PRIMARY KEY, collection VARBINARY(128) NOT NULL,
 epoch BIGINT UNSIGNED NOT NULL, records INT UNSIGNED NOT NULL, prepared BINARY(14) NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_identity (
 build BINARY(64) NOT NULL, source BINARY(64) NOT NULL, canonical BINARY(64) NOT NULL,
 PRIMARY KEY(build,source), KEY canonical_id(canonical), KEY source_id(source)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_asset_delivery (
 page INT UNSIGNED NOT NULL PRIMARY KEY, revision BIGINT UNSIGNED NOT NULL,
 filename VARBINARY(255) NOT NULL, image_hash VARBINARY(40) NOT NULL,
 signature BINARY(64) NOT NULL, build BINARY(64) NOT NULL, validated BINARY(14) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS /*_*/maw_issue_index (
 id BINARY(64) NOT NULL PRIMARY KEY, fingerprint BINARY(64) NOT NULL,
 priority INT UNSIGNED NOT NULL DEFAULT 0, uses INT UNSIGNED NOT NULL DEFAULT 0,
 KEY priority(priority,uses)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS /*_*/maw_guide_anchor (
 page INT UNSIGNED NOT NULL, target BINARY(64) NOT NULL, field VARBINARY(64) NOT NULL,
 anchor VARBINARY(160) NOT NULL, PRIMARY KEY(page,target,field)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS /*_*/maw_render (
 build BINARY(64) NOT NULL, record BINARY(64) NOT NULL, profile VARBINARY(64) NOT NULL,
 hash BINARY(64) NOT NULL, width INT UNSIGNED NOT NULL, height INT UNSIGNED NOT NULL,
 PRIMARY KEY(build,record,profile), KEY content_hash(hash)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS /*_*/maw_build_summary (
 build BINARY(64) NOT NULL PRIMARY KEY, counts BLOB NOT NULL,
 ready TINYINT UNSIGNED NOT NULL, dirty TINYINT UNSIGNED NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS /*_*/maw_guide_use (
 page INT UNSIGNED NOT NULL, target BINARY(64) NOT NULL, field VARBINARY(64) NOT NULL,
 anchor VARBINARY(640) NOT NULL, PRIMARY KEY(page,target,field,anchor), KEY target(target)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_gate (
 build BINARY(64) NOT NULL PRIMARY KEY, digest BINARY(64) NOT NULL,
 previous VARBINARY(64) NOT NULL, status VARBINARY(20) NOT NULL,
 checked BINARY(14) NOT NULL, findings INT UNSIGNED NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_gate_finding (
 build BINARY(64) NOT NULL, sequence INT UNSIGNED NOT NULL, target VARBINARY(64) NOT NULL,
 rule VARBINARY(64) NOT NULL, payload BLOB NOT NULL,
 PRIMARY KEY(build,sequence), KEY target(target)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_publication (
 id BINARY(64) NOT NULL PRIMARY KEY, sequence BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
 build BINARY(64) NOT NULL,
 epoch BIGINT UNSIGNED NOT NULL, review_digest BINARY(64) NOT NULL,
 published BINARY(14) NOT NULL, publisher VARBINARY(255) NOT NULL,
 UNIQUE KEY publication_order(sequence), KEY build_time(build,published)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_published_source (
 publication BINARY(64) NOT NULL, record BINARY(64) NOT NULL,
 source_build BINARY(64) NOT NULL, source_record BINARY(64) NOT NULL,
 fingerprint BINARY(64) NOT NULL,
 PRIMARY KEY(publication,record), KEY record(record)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_prepared_evidence (
 build BINARY(64) NOT NULL PRIMARY KEY,
 review_digest BINARY(64) NOT NULL, public_digest BINARY(64) NOT NULL,
 selection_digest VARBINARY(64) NOT NULL DEFAULT ''
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_public_edge (
 build BINARY(64) NOT NULL, src BINARY(64) NOT NULL, dst BINARY(64) NOT NULL,
 field VARBINARY(64) NOT NULL, quantity BLOB NOT NULL,
 PRIMARY KEY(build,src,dst,field), KEY incoming(build,dst)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_publication_plan (
 publication BINARY(64) NOT NULL PRIMARY KEY,
 digest BINARY(64) NOT NULL, payload MEDIUMBLOB NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_live_public (
 build BINARY(64) NOT NULL, record BINARY(64) NOT NULL, name VARBINARY(512) NOT NULL,
 kind VARBINARY(32) NOT NULL, family BINARY(64) NOT NULL, payload MEDIUMBLOB NOT NULL,
 PRIMARY KEY(build,record), KEY public_name(build,name(100)), KEY family(build,family)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS /*_*/maw_live_edge (
 build BINARY(64) NOT NULL, src BINARY(64) NOT NULL, dst BINARY(64) NOT NULL,
 field VARBINARY(64) NOT NULL, quantity BLOB NOT NULL,
 PRIMARY KEY(build,src,dst,field), KEY incoming(build,dst)
) ENGINE=InnoDB;
INSERT IGNORE INTO /*_*/maw_guide_use (page,target,field,anchor)
 SELECT d.page,d.target,d.field,COALESCE(a.anchor,'') FROM /*_*/maw_dependency d
 LEFT JOIN /*_*/maw_guide_anchor a ON a.page=d.page AND a.target=d.target AND a.field=d.field
 WHERE NOT EXISTS (SELECT 1 FROM /*_*/maw_guide_use u WHERE u.page=d.page AND u.target=d.target AND u.field=d.field);
