# den-hoag collectors: an aggregate is an entity. A hive has its own content (its `meta` sink) and selects its members
# with a predicate. It reads the fleet's colmena pool; it never re-evaluates a member.
{ sven, lib, ... }:
{
  sven.kinds.fleet.spawns.hive = _: sven.hive;
  sven.kinds.hive = {
    fields.environment = sven.kinds.environment;
    sinks.meta.reduce = sven.lib.reduce.merge;
    sinks.meta.out =
      {
        hive,
        meta,
        colmena,
        ...
      }:
      {
        colmenaHives.${hive.name} = {
          inherit meta;
        }
        // lib.filterAttrs (
          n: _: sven.host ? ${n} && sven.lib.same sven.host.${n}.environment hive.environment
        ) colmena;
      };
  };
  sven.hive = {
    prod.environment = sven.environment.prod;
    staging.environment = sven.environment.staging;
  };
  sven.aspects.hive-meta = {
    at = sven.kinds.hive;
    meta =
      { hive, ... }:
      {
        description = "the ${hive.name} hive";
        allowApplyAll = hive.name != "prod";
      };
  };
}
