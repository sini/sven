# A relation kind: a replica is a (db, region) pair; the fleet spawns only matching pairs.
{ sven, lib, ... }:
{
  sven.kinds.db.fields.zone = lib.types.str;
  sven.kinds.region.fields.zone = lib.types.str;
  sven.kinds.replica.fields = { db = sven.kinds.db; region = sven.kinds.region; };
  sven.db = { primary.zone = "eu"; backup.zone = "us"; };
  sven.region.eu.zone = "eu";
  sven.replica = { r1 = { db = sven.db.primary; region = sven.region.eu; }; r2 = { db = sven.db.backup; region = sven.region.eu; }; };
}
