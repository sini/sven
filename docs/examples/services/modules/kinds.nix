# A service instance is data: which machines take which role. Each machine spawns one `member` scope per role it has.
{ sven, lib, ... }:
let
  inherit (sven.lib) same is;
  membersOf =
    m:
    lib.listToAttrs (
      lib.concatLists (
        lib.mapAttrsToList (
          n: i:
          lib.concatMap (
            role:
            lib.optional (lib.any (same m) i.roles.${role}) (
              lib.nameValuePair "${n}.${role}" {
                instance = n;
                inherit role;
              }
            )
          ) (lib.attrNames i.roles)
        ) sven.instance
      )
    );
in
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks = {
      out.reduce = sven.lib.reduce.merge;
      exports.reduce = sven.lib.reduce.entries; # what members publish, with the scope that published it
    };
  };
  sven.kinds.instance.fields.roles = is lib.isAttrs; # role name -> host refs
  sven.kinds.host = {
    fields.addr = lib.types.str;
    spawns.member = membersOf;
    sinks.config = {
      reduce = sven.lib.reduce.merge;
      out =
        { host, config, ... }:
        {
          config.${host.name} = config;
        };
    };
  };
  sven.kinds.member = { }; # its elements go up to its machine

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
