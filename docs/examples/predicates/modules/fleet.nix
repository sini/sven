# Hosts with facts, guests (VMs) under hosts. An `active` output lists each aspect's scopes.
{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
  };
  sven.kinds.host = {
    fields = {
      cores = lib.types.int;
      gpu = sven.lib.opt lib.types.bool false;
    };
    spawns.guest = s: lib.filterAttrs (_: g: sven.lib.same g.on s) sven.guest;
  };
  sven.kinds.guest.fields.on = sven.kinds.host;

  sven.fleet.main = { };
  sven.host.big = {
    cores = 32;
    gpu = true;
  };
  sven.host.small.cores = 4;
  sven.guest.ci.on = sven.host.big;

}
