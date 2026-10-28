{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host = {
    fields.addr = lib.types.str;
    spawns.user = s: lib.filterAttrs (_: u: sven.lib.same u.on s) sven.user;
    sinks.packages = {
      reduce = sven.lib.reduce.set;
      out =
        { host, packages, ... }:
        {
          packages.${host.name} = packages;
        };
    };
  };
  sven.kinds.user.fields.on = sven.kinds.host;

  sven.fleet.main = { };
  sven.host.web.addr = "10.0.0.1";
  sven.user.ana.on = sven.host.web;
  sven.aspects.git = {
    at = [
      sven.kinds.host
      sven.kinds.user
    ];
    packages = "git";
  };
  sven.aspects.nginx = {
    at = sven.host.web;
    packages = "nginx";
  };
  sven.flake = { out, ... }: out;
}
