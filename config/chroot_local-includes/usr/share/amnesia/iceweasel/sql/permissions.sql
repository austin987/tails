PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE moz_hosts ( id INTEGER PRIMARY KEY,host TEXT,type TEXT,permission INTEGER);
INSERT INTO "moz_hosts" VALUES(1,'update.mozilla.org','install',1);
INSERT INTO "moz_hosts" VALUES(2,'addons.mozilla.org','install',1);
INSERT INTO "moz_hosts" VALUES(3,'boum.org','cookie',1);
INSERT INTO "moz_hosts" VALUES(4,'riseup.net','cookie',1);
INSERT INTO "moz_hosts" VALUES(5,'no-log.org','cookie',1);
COMMIT;
